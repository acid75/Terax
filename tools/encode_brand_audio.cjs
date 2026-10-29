// Authoring-only MP3 encoding. Pass the official lamejs lame.min.js path first.
const fs=require('node:fs'),vm=require('node:vm');
const context={};vm.createContext(context);vm.runInContext(fs.readFileSync(process.argv[2],'utf8'),context);
for(let i=3;i<process.argv.length;i+=2){
 const source=fs.readFileSync(process.argv[i]);
 const pcm=new Int16Array(source.buffer,source.byteOffset+44,(source.length-44)/2);
 const encoder=new context.lamejs.Mp3Encoder(1,48000,320),chunks=[];
 for(let at=0;at<pcm.length;at+=1152)chunks.push(Buffer.from(encoder.encodeBuffer(pcm.subarray(at,at+1152))));
 chunks.push(Buffer.from(encoder.flush()));fs.writeFileSync(process.argv[i+1],Buffer.concat(chunks));
}
