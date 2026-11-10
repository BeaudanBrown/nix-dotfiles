# Real fzf in a real popup on a disposable tmux server. No shared/live socket.
import os, sys, json, time, socket, subprocess, pathlib, pty, fcntl, termios, struct, threading, re, shutil
binary, fzf, root = sys.argv[1:]
stop=False
r=pathlib.Path(root); home=r/'home'; cache=r/'cache'; tmp=r/'tmp'; bins=r/'bin'
for p in (home/'documents',home/'monash',cache,tmp,bins):p.mkdir(parents=True,exist_ok=True)
repos=[]
for i in range(80):
 p=home/'documents'/('same-%03d'%i);p.mkdir();(p/'.git').mkdir();repos.append(p)
# Allowlist the environment, including a known non-login shell: absent SHELL
# makes tmux consult the host login shell, whose startup can rewrite PATH/TMPDIR
# and select an installed launcher instead of this candidate. Never inherit
# credentials, agent settings, shell startup hooks or production managed roots.
shell=shutil.which('sh');assert shell, 'controlled POSIX shell unavailable'
env=dict(HOME=str(home),SHELL=shell,LANG='C.UTF-8',XDG_CONFIG_HOME=str(home/'config'),XDG_DATA_HOME=str(home/'data'),XDG_STATE_HOME=str(home/'state'),XDG_CACHE_HOME=str(cache),XDG_RUNTIME_DIR=str(r/'unused-private-xdg'),TMPDIR=str(tmp),TERM='xterm-256color',PATH=str(bins)+':'+str(pathlib.Path(fzf).parent)+':'+os.environ['PATH'],FZF_DEFAULT_OPTS='',FZF_DEFAULT_OPTS_FILE='')
(bins/'tmux_project').symlink_to(binary)
rows=[dict(version=1,file=str(r/('native-'+c+'.jsonl')),id='native-'+c,cwd=str(repos[i]),title='same native '+c,running=False) for i,c in enumerate(('a','b'))]
mode=r/'mode.json';mode.write_text('{}');data=r/'native.json';data.write_text(json.dumps(rows))
legacy=bins/'pi-managed-session'
legacy.write_text('#!'+shell+'\n: > '+str(r/'forbidden-cli')+'\nexit 99\n');legacy.chmod(0o700)
# Local CLI fixture only. There is deliberately no bridge/Matrix/host socket.
helper=bins/'pi-session'
helper.write_text(f'''#!{sys.executable}
import json,sys,time,pathlib
assert sys.argv[1:]==['list','--all']
mode=json.loads(pathlib.Path({str(mode)!r}).read_text())
time.sleep(mode.get('delay',0))
if mode.get('error'):sys.exit(2)
print(pathlib.Path({str(data)!r}).read_text())
''');helper.chmod(0o700)
git=bins/'git';git.write_text('#!/bin/sh\n: > '+str(r/'forbidden-git')+'\nexit 99\n');git.chmod(0o700)
sock=str(r/'server.sock')
def tmux(*args):return subprocess.check_output(['tmux','-f','/dev/null','-S',sock,*args],env=env,stderr=subprocess.PIPE).decode().strip()
master,slave=pty.openpty();fcntl.ioctl(slave,termios.TIOCSWINSZ,struct.pack('HHHH',35,140,0,0))
client=None;stream=bytearray();lock=threading.Lock()
ansi=re.compile(rb'\x1b\[[0-?]*[ -/]*[@-~]')
def drain():
 while not stop:
  try:
   chunk=os.read(master,65536)
   if b'\x1b[6n' in chunk:os.write(master,b'\x1b[1;1R')
   with lock:stream.extend(chunk)
  except OSError:return

def request(ui,body=None):
 c=socket.socket(socket.AF_UNIX);c.settimeout(.5);c.connect(str(ui/'ui.sock'));payload=(body or '').encode()
 header=('POST / HTTP/1.0\r\nContent-Length: %d\r\n\r\n'%len(payload)).encode() if body is not None else b'GET /?limit=8192 HTTP/1.0\r\n\r\n'
 c.sendall(header+payload);out=b''
 while True:
  b=c.recv(65536)
  if not b:break
  out+=b
 c.close();data=out.split(b'\r\n\r\n',1)[-1]
 return json.loads(data) if body is None else None

def wait(predicate,seconds=5):
 end=time.monotonic()+seconds
 while time.monotonic()<end:
  try:
   value=predicate()
   if value:return value
  except (OSError,ValueError,KeyError):pass
  time.sleep(.002)
 raise AssertionError('timed out')

def one(kind,identity=False):
 if kind=='cold':shutil.rmtree(cache/'tmux-project',ignore_errors=True)
 mode.write_text(json.dumps({'error':kind=='error','delay':.35 if identity else 0}))
 with lock:stream.clear()
 started=time.monotonic();os.write(master,b'\x1b[24~')
 ui=wait(lambda:next((p for p in tmp.glob('tmux-picker-*') if (p/'ui.sock').exists()),None))
 observed={'raw_ms':None,'native_ms':None}
 def readstate():
  state=request(ui)
  for key,prefix in [('raw_ms','path:'),('native_ms','pi:')]:
   if observed[key] is None and any(x['text'].startswith(prefix) for x in state['matches']):observed[key]=round((time.monotonic()-started)*1000,2)
  return state
 def prompt():
  with lock:return b'PROJECT>' in ansi.sub(b'',bytes(stream))
 try:wait(prompt)
 except Exception:
  with lock:print('terminal:',b' '.join(re.sub(rb'[^ -~]',b' ',ansi.sub(b'',bytes(stream))).split())[-1600:],flush=True)
  print('ui files:',list(ui.glob('*')),flush=True)
  raise
 ui_ms=(time.monotonic()-started)*1000
 state=wait(lambda:(s if (s:=readstate()).get('current') else None));first_ms=(time.monotonic()-started)*1000
 if identity:
  wait(lambda:readstate()['totalCount']>20)
  assert not any(x['text'].startswith('pi:') for x in readstate()['matches']), 'late-inventory fixture was not late'
  request(ui,'change-query(same)');state=wait(lambda:(s if (s:=readstate())['query']=='same' else None))
  target='session:same' if identity=='remove' else 'path:'+str(repos[50]);index=next(i for i,item in enumerate(state['matches']) if item['text'].split('\t')[0]==target)
  request(ui,'pos(%d)'%(index+1));wait(lambda:readstate()['current']['text'].split('\t')[0]==target)
 def complete():readstate();return (ui/'discovery.json').exists()
 wait(complete);full_ms=(time.monotonic()-started)*1000
 state=readstate()
 if identity:
  assert state['query']=='same',state
  if identity!='remove':assert state['current']['text'].split('\t')[0]==target,state
  else:
   os.write(master,b'\r');time.sleep(.1);assert ui.exists(),'removed selection silently accepted another row'
  assert any(x['text'].split('\t')[0]=='path:'+str(repos[1]) for x in state['matches']),state
  assert sum(x['text'].startswith('pi:') for x in state['matches'])==2,state
 if kind=='error':assert not any(x['text'].startswith('pi:') for x in state['matches'])
 else:assert sum(x['text'].startswith('pi:') for x in state['matches'])==2,state
 if (home/'documents'/'same-new').exists():
  keys={x['text'].split('\t')[0] for x in state['matches']}
  assert 'path:'+str(home/'documents'/'same-new') in keys,'addition not refreshed'
  assert 'path:'+str(repos[79]) not in keys,'removed path retained'
 assert not (r/'forbidden-git').exists(),'Git subprocess during discovery'
 assert not (r/'forbidden-cli').exists(),'unexpected CLI fallback'
 os.write(master,b'\x1b');wait(lambda:not ui.exists());time.sleep(.02)
 return dict(ui_ms=round(ui_ms,2),first_ms=round(first_ms,2),full_ms=round(full_ms,2),**observed)

try:
 tmux('new-session','-d','-s','same','-c',str(repos[0]),'sleep 120')
 tmux('set-option','-t','same','@project_role','root');tmux('set-option','-t','same','@project_root',str(repos[0]))
 rows[0].update(running=True,pane=tmux('display-message','-p','#{pane_id}'),serverPid=int(tmux('display-message','-p','#{pid}')));data.write_text(json.dumps(rows))
 tmux('bind-key','-n','F12','run-shell',binary+' launcher-popup "#{client_name}"')
 def setup():os.setsid();fcntl.ioctl(slave,termios.TIOCSCTTY,0)
 client=subprocess.Popen(['tmux','-S',sock,'attach-session','-t','same'],stdin=slave,stdout=slave,stderr=slave,env=env,preexec_fn=setup)
 threading.Thread(target=drain,daemon=True).start();wait(lambda:tmux('list-clients','-F','#{client_name}'));time.sleep(.1)
 identity=one('cold',True)
 removed=one('cold','remove')
 results={kind:[one(kind) for _ in range(7)] for kind in ('cold','warm','error')}
 fresh=home/'documents'/'same-new';fresh.mkdir();(fresh/'.git').mkdir();shutil.rmtree(repos[79]);refreshed=one('warm')
 # Exit while read-only native metadata is delayed; no Pi is cancelled/replayed.
 mode.write_text(json.dumps({'delay':1.5}));os.write(master,b'\x1b[24~')
 cancelling=wait(lambda:next((p for p in tmp.glob('tmux-picker-*') if (p/'ui.sock').exists()),None))
 wait(lambda:request(cancelling).get('current'))
 aborted=time.monotonic();os.write(master,b'\x1b');wait(lambda:not cancelling.exists(),.9);cancel_ms=(time.monotonic()-aborted)*1000
 print(json.dumps({'identity_reload':identity,'removed_selection':removed,'cache_refresh':refreshed,'cancel_ms':round(cancel_ms,2),'public_transport':'relay-independent pi-session JSON CLI','timings':results}),flush=True)
except Exception:
 with lock:print('terminal failure:',b' '.join(re.sub(rb'[^ -~]',b' ',ansi.sub(b'',bytes(stream))).split())[-1600:],flush=True)
 print('remaining UI dirs:',list(tmp.glob('*')),flush=True)
 print('clients:',tmux('list-clients','-F','#{client_name}|#{client_pid}'),flush=True)
 raise
finally:
 stop=True
 try:tmux('kill-server')
 except Exception:pass
 if client is not None:
  try:client.wait(timeout=2)
  except subprocess.TimeoutExpired:client.kill();client.wait()
 os.close(master);os.close(slave)
