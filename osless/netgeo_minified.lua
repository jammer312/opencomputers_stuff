local a=component or require"component"local b=function(c)local d=a.list(c)()return d and a.proxy(d)or error("Component not found: "..c)end;local e=b"geolyzer"if not e then error"Need geolyzer to function"end;local function f(g)return g*2.0/33.0 end;local function h(i,j,k)return math.abs(i-k)>j end;local function l(m,n,o,p)m=m-1;local q,r,s;q=m%n;s=math.floor(m/n)%p;r=math.floor(m/n/p)return q,r,s end;local function t(u,v,w,n,o,p,x,y,z,A)local B=n*o*p;local function C(m)local q,r,s=l(m,n,o,p)q=q+u;r=r+v;s=s+w;return f(math.sqrt(q*q+r*r+s*s))end;local D={}local E={}local F={}local G={}local H=false;A=A or-1;while not H and A~=0 do D,err=e.scan(u,w,v,n,o,p)if err~=nil then error("Scan error: "..err)end;A=A-1;H=true;for m=1,B do local j=C(m)local i=D[m]if E[m]then if h(i,j,y)then E[m]=false end elseif E[m]==nil then if h(i,j,y)then E[m]=false else F[m]=F[m]or h(i,j,x)G[m]=G[m]or h(i,j,z)if G[m]and F[m]then E[m]=true else H=false end end end end end;return E end;local I=b"modem"I.setWakeMessage"netgeo_wake"I.setStrength(400)local J=312;I.open(J)local function K(...)I.broadcast(312,...)end;local L=nil;local function M(...)I.send(L,J,...)end;local N={}local O=0;local P=1;local Q=1;local function R(S)if#N==0 then O=1;P=1 else O=O+1 end;table.insert(N,S)end;local function T(U)U=U or 600;while O>=P do local V=I.maxPacketSize()local W=V-2*4-3-6-8;while O>=P+1 and string.len(N[P])+string.len(N[P+1])+1<=W do N[P+1]=N[P].."\n"..N[P+1]N[P]=nil;P=P+1 end;M("sdp","packet",Q,N[P])local X=computer.uptime()+U;while true do if computer.uptime()>X then break end;local Y,Z,_,a0,o,a1,a2,a3=computer.pullSignal(X-computer.uptime())if Y=="modem_message"and _==L and a1=="sdp"and a2=="ok"and a3==Q then N[P]=nil;P=P+1;Q=Q+1;computer.beep()break end end;if computer.uptime()>X then break end end end;local function a4(...)local a5=false;while not a5 do M("sdp",...)local X=computer.uptime()+1;while computer.uptime()<X do local Y,Z,_,a0,o,a1,a2=computer.pullSignal(X-computer.uptime())if Y=="modem_message"and _==L and a1=="sdp"and a2=="ok"then a5=true;break end end end end;local function a6(u,v,w,a7,a8,p,a9)local function aa(m)return l(m,4,4,4)end;local ab=1;for q=-32,28,4 do for r=-32,28,4 do for s=-32,28,4 do local E=t(q,r,s,4,4,4,a7,a8,p,a9)ab=ab+1;for m=1,64 do local ac,ad,ae=aa(m)ac=ac+q+u;ad=ad+r+v;ae=ae+s+w;local af="("..ac..", "..ad..", "..ae..") -> "if E[m]==nil then R(af.."undecided")elseif E[m]then R(af.."found")end end;if(ab-1)%512==0 then R("Progress: "..(ab-1)/4096.0*100 .."% scanned.")T(5)end end end end end;K"netgeo_ready"while true do local Y,Z,_,a0,o,ag,ah,ai,aj,ak,al,am,an=computer.pullSignal()if Y~="modem_message"then else L=_;if ag=="netgeo_wake"then M"netgeo_ready"elseif ag=="netgeo_scan"then a4("start")R"netgeo_scanning"a6(ah,ai,aj,ak,al,am,an)R"netgeo_scan_done"T()a4("end")computer.shutdown()end end end