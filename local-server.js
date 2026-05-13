const http = require('http');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const port = 8080;
const types = {'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.sql':'text/plain; charset=utf-8','.txt':'text/plain; charset=utf-8','.png':'image/png','.jpg':'image/jpeg','.jpeg':'image/jpeg','.webp':'image/webp','.svg':'image/svg+xml'};
const server = http.createServer((req,res)=>{
  let file = decodeURIComponent(req.url.split('?')[0]);
  if(file === '/' || file === '') file = '/user-app.html';
  const full = path.join(__dirname, file);
  if(!full.startsWith(__dirname)) { res.writeHead(403); res.end('Forbidden'); return; }
  fs.readFile(full, (err, data)=>{
    if(err){ res.writeHead(404); res.end('Not found'); return; }
    res.writeHead(200, {'Content-Type': types[path.extname(full)] || 'application/octet-stream'});
    res.end(data);
  });
});
server.listen(port, ()=>{
  const url = `http://localhost:${port}/user-app.html`;
  console.log(`RTN Chat running: ${url}`);
  const cmd = process.platform === 'win32' ? `start ${url}` : process.platform === 'darwin' ? `open ${url}` : `xdg-open ${url}`;
  exec(cmd);
});
