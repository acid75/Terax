#include "desktop_wave.h"

#include <d3d11.h>
#include <d3dcompiler.h>
#include <dcomp.h>
#include <dxgi1_2.h>
#include <wrl/client.h>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <mutex>
#include <thread>

using Microsoft::WRL::ComPtr;
namespace {
constexpr wchar_t kWindowClass[] = L"TeraxDesktopWave";
constexpr char kShader[] = R"(
Texture2D desktopImage : register(t0);
SamplerState imageSampler : register(s0);
cbuffer Frame : register(b0) { float elapsed; float aspect; float reduced; float unused; };
struct Vertex { float4 position : SV_POSITION; float2 uv : TEXCOORD0; };
Vertex VS(uint id : SV_VertexID) {
  Vertex v;
  v.uv = float2((id << 1) & 2, id & 2);
  v.position = float4(v.uv * float2(2,-2) + float2(-1,1),0,1);
  return v;
}
float4 PS(Vertex v) : SV_TARGET {
  float t = saturate(elapsed / 1.8);
  float2 delta = (v.uv - float2(.5,1.04)) * float2(aspect,1);
  float radius = length(delta);
  float waveRadius = t * 1.55;
  float band = exp(-pow((radius-waveRadius)/.075,2));
  float envelope = smoothstep(0,.09,t) * (1-smoothstep(.68,1,t));
  float2 direction = delta / max(radius,.001) / float2(aspect,1);
  float displacement = sin((radius-waveRadius)*65) * band * .013 * envelope * (1-reduced);
  float3 color = desktopImage.Sample(imageSampler,saturate(v.uv + direction*displacement)).rgb;
  color += float3(.055,.105,.14) * band * envelope * (.7 + .3*(1-reduced));
  // Premultiplied composition: the desktop returns continuously as this fades.
  float alpha = envelope;
  return float4(saturate(color)*alpha,alpha);
}
)";

LRESULT CALLBACK WaveWindowProc(HWND hwnd, UINT message, WPARAM w, LPARAM l) {
  if (message == WM_NCHITTEST) return HTTRANSPARENT;
  if (message == WM_MOUSEACTIVATE) return MA_NOACTIVATE;
  if (message == WM_ERASEBKGND) return 1;
  return DefWindowProc(hwnd, message, w, l);
}

// Fallback also handles rotated monitors and remote sessions where DXGI desktop
// duplication is unavailable. Its short-lived DIB remains in process memory.
bool CaptureGdi(const RECT& bounds, ID3D11Device* device,
                ID3D11Texture2D** texture) {
  int width = bounds.right - bounds.left, height = bounds.bottom - bounds.top;
  HDC screen = GetDC(nullptr);
  if (!screen) return false;
  HDC memory = CreateCompatibleDC(screen);
  BITMAPINFO info = {};
  info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  info.bmiHeader.biWidth = width;
  info.bmiHeader.biHeight = -height;
  info.bmiHeader.biPlanes = 1;
  info.bmiHeader.biBitCount = 32;
  info.bmiHeader.biCompression = BI_RGB;
  void* pixels = nullptr;
  HBITMAP bitmap = CreateDIBSection(screen, &info, DIB_RGB_COLORS, &pixels, nullptr, 0);
  bool success = false;
  if (memory && bitmap && pixels) {
    auto old = SelectObject(memory, bitmap);
    if (BitBlt(memory, 0, 0, width, height, screen, bounds.left, bounds.top,
               SRCCOPY | CAPTUREBLT)) {
      D3D11_TEXTURE2D_DESC desc = {};
      desc.Width = width; desc.Height = height;
      desc.MipLevels = desc.ArraySize = 1;
      desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
      desc.SampleDesc.Count = 1;
      desc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
      D3D11_SUBRESOURCE_DATA data = {pixels, static_cast<UINT>(width * 4), 0};
      success = SUCCEEDED(device->CreateTexture2D(&desc, &data, texture));
    }
    SelectObject(memory, old);
  }
  if (bitmap) DeleteObject(bitmap);
  if (memory) DeleteDC(memory);
  ReleaseDC(nullptr, screen);
  return success;
}
}  // namespace

struct DesktopWave::Impl {
  std::thread thread;
  std::atomic<bool> running{false}, stop{false};
  mutable std::mutex mutex;
  std::condition_variable ready;
  bool initialized = false, succeeded = false;
  std::string failure;

  void Signal(bool ok, const char* reason = "") {
    std::lock_guard<std::mutex> lock(mutex);
    succeeded = ok;
    initialized = true;
    failure = reason;
    ready.notify_all();
  }

  void Run(HMONITOR monitor, bool reduced) {
    HRESULT com = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    HWND window = nullptr;
    auto render = [&]() -> const char* {
      MONITORINFO mi = {sizeof(mi)};
      if (!GetMonitorInfo(monitor, &mi)) return "Monitor is unavailable.";
      RECT bounds = mi.rcMonitor;
      UINT width = bounds.right-bounds.left, height = bounds.bottom-bounds.top;
      ComPtr<IDXGIFactory1> factory;
      if (FAILED(CreateDXGIFactory1(IID_PPV_ARGS(&factory)))) return "DXGI factory failed.";
      ComPtr<IDXGIAdapter1> selectedAdapter;
      ComPtr<IDXGIOutput1> selectedOutput;
      for (UINT a = 0; ; ++a) {
        ComPtr<IDXGIAdapter1> adapter;
        if (factory->EnumAdapters1(a, &adapter) == DXGI_ERROR_NOT_FOUND) break;
        for (UINT o = 0; ; ++o) {
          ComPtr<IDXGIOutput> output;
          if (adapter->EnumOutputs(o, &output) == DXGI_ERROR_NOT_FOUND) break;
          DXGI_OUTPUT_DESC desc = {};
          if (SUCCEEDED(output->GetDesc(&desc)) && desc.Monitor == monitor) {
            selectedAdapter = adapter;
            if (desc.Rotation == DXGI_MODE_ROTATION_IDENTITY) output.As(&selectedOutput);
            break;
          }
        }
        if (selectedAdapter) break;
      }
      ComPtr<ID3D11Device> device;
      ComPtr<ID3D11DeviceContext> context;
      HRESULT hr = D3D11CreateDevice(selectedAdapter.Get(), selectedAdapter ? D3D_DRIVER_TYPE_UNKNOWN : D3D_DRIVER_TYPE_HARDWARE,
          nullptr, D3D11_CREATE_DEVICE_BGRA_SUPPORT, nullptr, 0, D3D11_SDK_VERSION, &device, nullptr, &context);
      if (FAILED(hr)) {
        selectedOutput.Reset();
        hr = D3D11CreateDevice(nullptr,D3D_DRIVER_TYPE_WARP,nullptr,D3D11_CREATE_DEVICE_BGRA_SUPPORT,
            nullptr,0,D3D11_SDK_VERSION,&device,nullptr,&context);
      }
      if (FAILED(hr)) return "Direct3D device creation failed.";
      ComPtr<ID3D11Texture2D> snapshot;
      if (selectedOutput) {
        ComPtr<IDXGIOutputDuplication> duplication;
        if (SUCCEEDED(selectedOutput->DuplicateOutput(device.Get(), &duplication))) {
          DXGI_OUTDUPL_FRAME_INFO frame = {};
          ComPtr<IDXGIResource> resource;
          if (SUCCEEDED(duplication->AcquireNextFrame(150, &frame, &resource))) {
            ComPtr<ID3D11Texture2D> source;
            if (SUCCEEDED(resource.As(&source))) {
              D3D11_TEXTURE2D_DESC desc = {};
              source->GetDesc(&desc);
              desc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
              desc.MiscFlags = desc.CPUAccessFlags = 0;
              desc.Usage = D3D11_USAGE_DEFAULT;
              if (desc.Width == width && desc.Height == height &&
                  SUCCEEDED(device->CreateTexture2D(&desc, nullptr, &snapshot)))
                context->CopyResource(snapshot.Get(), source.Get());
            }
            duplication->ReleaseFrame();
          }
        }
      }
      if (!snapshot && !CaptureGdi(bounds,device.Get(),&snapshot)) return "Desktop capture failed.";
      WNDCLASS wc = {};
      wc.lpfnWndProc = WaveWindowProc; wc.hInstance = GetModuleHandle(nullptr);
      wc.lpszClassName = kWindowClass;
      if (!RegisterClass(&wc) && GetLastError()!=ERROR_CLASS_ALREADY_EXISTS) return "Overlay registration failed.";
      window = CreateWindowEx(WS_EX_TOPMOST|WS_EX_TOOLWINDOW|WS_EX_NOACTIVATE|WS_EX_TRANSPARENT|WS_EX_LAYERED|WS_EX_NOREDIRECTIONBITMAP,
          kWindowClass,L"Terax \x00b7 efecto de escritorio",WS_POPUP,bounds.left,bounds.top,width,height,nullptr,nullptr,wc.hInstance,nullptr);
      if (!window) return "Overlay window creation failed.";
      // Layered + transparent explicitly routes mouse input to windows beneath
      // us, including windows owned by other processes/threads.
      if (!SetLayeredWindowAttributes(window,0,255,LWA_ALPHA)) return "Overlay transparency failed.";
      ComPtr<IDXGIDevice> dxgiDevice;
      device.As(&dxgiDevice);
      ComPtr<IDXGIAdapter> adapter;
      dxgiDevice->GetAdapter(&adapter);
      ComPtr<IDXGIFactory2> factory2;
      if (FAILED(adapter->GetParent(IID_PPV_ARGS(&factory2)))) return "Composition factory failed.";
      DXGI_SWAP_CHAIN_DESC1 swapDesc = {};
      swapDesc.Width=width; swapDesc.Height=height; swapDesc.Format=DXGI_FORMAT_B8G8R8A8_UNORM;
      swapDesc.SampleDesc.Count=1; swapDesc.BufferUsage=DXGI_USAGE_RENDER_TARGET_OUTPUT;
      swapDesc.BufferCount=2; swapDesc.SwapEffect=DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;
      swapDesc.AlphaMode=DXGI_ALPHA_MODE_PREMULTIPLIED;
      ComPtr<IDXGISwapChain1> swap;
      if (FAILED(factory2->CreateSwapChainForComposition(device.Get(),&swapDesc,nullptr,&swap))) return "Composition swap chain failed.";
      ComPtr<IDCompositionDevice> composition;
      ComPtr<IDCompositionTarget> target;
      ComPtr<IDCompositionVisual> visual;
      if (FAILED(DCompositionCreateDevice(dxgiDevice.Get(),IID_PPV_ARGS(&composition))) ||
          FAILED(composition->CreateTargetForHwnd(window,TRUE,&target)) ||
          FAILED(composition->CreateVisual(&visual)) || FAILED(visual->SetContent(swap.Get())) ||
          FAILED(target->SetRoot(visual.Get())) || FAILED(composition->Commit()) ||
          FAILED(composition->WaitForCommitCompletion())) return "Desktop composition failed.";
      ComPtr<ID3DBlob> vsCode, psCode, errors;
      if (FAILED(D3DCompile(kShader,sizeof(kShader),nullptr,nullptr,nullptr,"VS","vs_4_0",0,0,&vsCode,&errors)) ||
          FAILED(D3DCompile(kShader,sizeof(kShader),nullptr,nullptr,nullptr,"PS","ps_4_0",0,0,&psCode,&errors))) return "Wave shader compilation failed.";
      ComPtr<ID3D11VertexShader> vs;
      ComPtr<ID3D11PixelShader> ps;
      ComPtr<ID3D11ShaderResourceView> image;
      ComPtr<ID3D11Texture2D> back;
      ComPtr<ID3D11RenderTargetView> rtv;
      if (FAILED(device->CreateVertexShader(vsCode->GetBufferPointer(),vsCode->GetBufferSize(),nullptr,&vs)) ||
          FAILED(device->CreatePixelShader(psCode->GetBufferPointer(),psCode->GetBufferSize(),nullptr,&ps)) ||
          FAILED(device->CreateShaderResourceView(snapshot.Get(),nullptr,&image)) ||
          FAILED(swap->GetBuffer(0,IID_PPV_ARGS(&back))) ||
          FAILED(device->CreateRenderTargetView(back.Get(),nullptr,&rtv))) return "Wave GPU resources failed.";
      D3D11_SAMPLER_DESC samplerDesc = {};
      samplerDesc.Filter=D3D11_FILTER_MIN_MAG_MIP_LINEAR;
      samplerDesc.AddressU=samplerDesc.AddressV=samplerDesc.AddressW=D3D11_TEXTURE_ADDRESS_CLAMP;
      samplerDesc.MaxLOD=D3D11_FLOAT32_MAX;
      ComPtr<ID3D11SamplerState> sampler;
      D3D11_BUFFER_DESC bufferDesc = {};
      bufferDesc.ByteWidth=16; bufferDesc.Usage=D3D11_USAGE_DEFAULT; bufferDesc.BindFlags=D3D11_BIND_CONSTANT_BUFFER;
      ComPtr<ID3D11Buffer> constants;
      if (FAILED(device->CreateSamplerState(&samplerDesc,&sampler)) ||
          FAILED(device->CreateBuffer(&bufferDesc,nullptr,&constants))) return "Wave shader setup failed.";
      D3D11_VIEWPORT viewport = {0,0,static_cast<float>(width),static_cast<float>(height),0,1};
      context->RSSetViewports(1,&viewport);
      context->OMSetRenderTargets(1,rtv.GetAddressOf(),nullptr);
      context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
      context->VSSetShader(vs.Get(),nullptr,0); context->PSSetShader(ps.Get(),nullptr,0);
      context->PSSetShaderResources(0,1,image.GetAddressOf());
      context->PSSetSamplers(0,1,sampler.GetAddressOf());
      context->PSSetConstantBuffers(0,1,constants.GetAddressOf());
      const float clear[4] = {};
      context->ClearRenderTargetView(rtv.Get(),clear);
      if (FAILED(swap->Present(1,0))) return "Overlay presentation failed.";
      ShowWindow(window,SW_SHOWNOACTIVATE);
      running=true;
      // Report success only after a visible frame has actually been presented.
      // Otherwise Dart suppresses its fallback even when rendering fails.
      auto start = std::chrono::steady_clock::now();
      bool checkedVisibleFrame = false;
      bool reportedVisibleFrame = false;
      while (!stop) {
        MSG msg;
        while (PeekMessage(&msg,nullptr,0,0,PM_REMOVE)) {
          TranslateMessage(&msg); DispatchMessage(&msg);
        }
        float seconds = std::chrono::duration<float>(std::chrono::steady_clock::now()-start).count();
        if (seconds>=1.8f) break;
        float values[4] = {seconds,static_cast<float>(width)/height,reduced ? 1.f : 0.f,0};
        // Flip-model Present unbinds back buffer 0, including the initial clear.
        // Bind it for EVERY frame, otherwise Draw silently has nowhere to write.
        context->OMSetRenderTargets(1,rtv.GetAddressOf(),nullptr);
        ComPtr<ID3D11RenderTargetView> boundTarget;
        context->OMGetRenderTargets(1, &boundTarget, nullptr);
        if (!boundTarget) return "Frame has no render target after Present.";
        context->UpdateSubresource(constants.Get(),0,nullptr,values,0,0);
        context->Draw(3,0);
        if (!checkedVisibleFrame && seconds >= .2f) {
          // Check only alpha, never read/log/save captured desktop colors.
          D3D11_TEXTURE2D_DESC checkDesc = {};
          checkDesc.Width=checkDesc.Height=checkDesc.MipLevels=checkDesc.ArraySize=1;
          checkDesc.Format=DXGI_FORMAT_B8G8R8A8_UNORM;
          checkDesc.SampleDesc.Count=1;
          checkDesc.Usage=D3D11_USAGE_STAGING;
          checkDesc.CPUAccessFlags=D3D11_CPU_ACCESS_READ;
          ComPtr<ID3D11Texture2D> pixel;
          if (FAILED(device->CreateTexture2D(&checkDesc,nullptr,&pixel))) return "Frame visibility check failed.";
          D3D11_BOX area = {width/2,height/2,0,width/2+1,height/2+1,1};
          context->CopySubresourceRegion(pixel.Get(),0,0,0,0,back.Get(),0,&area);
          D3D11_MAPPED_SUBRESOURCE mapped = {};
          if (FAILED(context->Map(pixel.Get(),0,D3D11_MAP_READ,0,&mapped))) return "Frame readback failed.";
          const auto alpha = static_cast<const unsigned char*>(mapped.pData)[3];
          context->Unmap(pixel.Get(),0);
          if (alpha < 16) return "Rendered frame is transparent; desktop effect is not visible.";
          checkedVisibleFrame=true;
        }
        if (FAILED(swap->Present(1,0))) return "Overlay presentation interrupted.";
        if (checkedVisibleFrame && !reportedVisibleFrame) {
          reportedVisibleFrame = true;
          Signal(true);
        }
      }
      if (!reportedVisibleFrame) return "Overlay stopped before a visible frame.";
      ShowWindow(window,SW_HIDE);
      context->ClearState();
      context->Flush();
      return nullptr;
    };
    const char* failureReason = nullptr;
    try { failureReason = render(); }
    catch (...) { failureReason = "Desktop wave initialization failed."; }
    if (window) DestroyWindow(window);
    running=false;
    if (failureReason) Signal(false,failureReason);
    if (SUCCEEDED(com)) CoUninitialize();
  }
};

DesktopWave::DesktopWave() : impl_(std::make_unique<Impl>()) {}
DesktopWave::~DesktopWave() { Stop(); }
bool DesktopWave::Play(HWND owner, bool reducedMotion) {
  if (active()) return false;
  Stop();
  HMONITOR monitor = MonitorFromWindow(owner,MONITOR_DEFAULTTOPRIMARY);
  {
    std::lock_guard<std::mutex> lock(impl_->mutex);
    impl_->initialized=false; impl_->succeeded=false; impl_->failure.clear();
  }
  impl_->stop=false;
  try { impl_->thread=std::thread([this,monitor,reducedMotion] { impl_->Run(monitor,reducedMotion); }); }
  catch (...) { impl_->Signal(false,"Render thread creation failed."); return false; }
  std::unique_lock<std::mutex> lock(impl_->mutex);
  impl_->ready.wait(lock,[this] { return impl_->initialized; });
  return impl_->succeeded;
}
bool DesktopWave::active() const { return impl_->running; }
std::string DesktopWave::error() const {
  std::lock_guard<std::mutex> lock(impl_->mutex);
  return impl_->failure;
}
void DesktopWave::Stop() {
  impl_->stop=true;
  if (impl_->thread.joinable()) impl_->thread.join();
}
