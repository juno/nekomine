-- neko mine (pico-8): game, drawing, input, save data
-- save slots: 0-2 best time per level, 3-10 dex counts, 11 muted
cartdata("nekomine_pico8")
poke(0x5f2d,1) -- mouse
names={"chatora","saba","kuro","shiro","hachi","mike","siam","maneki"}
lvn={"kitten","cat","boss cat"}
-- rows cols cats cell-width row-pitch
lvs={{9,9,10,12,10},{12,12,26,10,9},{14,14,36,8,7}}
lv,st,cur,muted,oy=1,"title",1,dget(11),14

function snd(n) if muted==0 then sfx(n) end end
menuitem(1,"title",function() st="title" end)
menuitem(2,"sound on/off",function() muted=1-muted dset(11,muted) snd(1) return true end)

function fmt(s) return s==0 and "--" or flr(s).."."..flr(s*10)%10 end
function ctext(s,y,c) print(s,64-#s*2,y,c) end

function setlv()
 rows,cols,cats,cw,py=unpack(lvs[lv])
 ry,hw=flr(py*2/3),cw/2-1
 hr=hw-1
 ox=flr((128-cols*cw-cw/2)/2)
end

function newgame()
 setlv()
 st,b,gen,over,t0,emsg="play"
 pmx,pmy,pmb=stat(32),stat(33),stat(34)
 cur=flr(rows/2)*cols+flr(cols/2)+1
end

function ctr(k)
 local r,c=flr((k-1)/cols),(k-1)%cols
 return ox+c*cw+(r%2)*cw/2+cw/2,oy+r*py+ry
end

function pick(mx,my)
 local best,bd
 bd=cw*cw/3
 for k=1,rows*cols do
  local x,y=ctr(k)
  if abs(x-mx)<cw and abs(y-my)<cw then
   local d=(x-mx)^2+(y-my)^2
   if d<bd then best,bd=k,d end
  end
 end
 return best
end

function fin(won)
 over=won and "win" or "lose"
 tend=time()-t0
 snd(won and 4 or 3)
 local cs=caught(b,won)
 nnew=0
 for br in all(cs) do
  local n=dget(2+br)
  if n==0 then nnew+=1 end
  dset(2+br,n+1)
 end
 ncaught=#cs
 newbest=false
 if won then
  local bt=dget(lv-1)
  if bt==0 or tend<bt then dset(lv-1,tend) newbest=true end
 end
end

function open(k)
 local was=b.open[k]
 if reveal(b,k)=="boom" then fin(false)
 elseif iswon(b) then fin(true)
 elseif b.open[k] and not was then snd(0) end
end

function act(k,flag)
 if over or gen then return end
 emsg=nil
 if flag then
  if b then
   local was=b.flag[k]
   toggleflag(b,k)
   if b.flag[k]!=was then snd(was and 2 or 1) end
  end
 elseif b then open(k)
 else
  gk=k
  gen=cocreate(function() b=createboard(rows,cols,cats,k,yield) end)
 end
end

function _init() setlv() end

function _update()
 if st=="title" then
  if btnp(2) then lv=lv==1 and 3 or lv-1 end
  if btnp(3) then lv=lv%3+1 end
  if btnp(4) then newgame() end
  if btnp(5) then st="dex" end
 elseif st=="dex" then
  if btnp(4) or btnp(5) then st="title" end
 else
  if gen then
   -- build the no-guess board a few tries per frame so the screen stays alive
   while costatus(gen)!="dead" and stat(1)<.8 do coresume(gen) end
   if costatus(gen)=="dead" then
    gen=nil
    if b then t0=time() open(gk) else emsg="bad luck, try again" end
   end
   return
  end
  local r,c=flr((cur-1)/cols),(cur-1)%cols
  if btnp(0) then c=max(0,c-1) end
  if btnp(1) then c=min(cols-1,c+1) end
  if btnp(2) then r=max(0,r-1) end
  if btnp(3) then r=min(rows-1,r+1) end
  cur=r*cols+c+1
  local mx,my,mb=stat(32),stat(33),stat(34)
  if mx!=pmx or my!=pmy then cur=pick(mx,my) or cur mused=true end
  local m=pick(mx,my)
  if m then
   if band(mb,1)>0 and band(pmb or 0,1)==0 then act(m) end
   if band(mb,2)>0 and band(pmb or 0,2)==0 then act(m,true) end
  end
  pmx,pmy,pmb=mx,my,mb
  if btnp(4) then if over then newgame() else act(cur) end end
  if btnp(5) then if over then st="title" else act(cur,true) end end
 end
end

-- hexagon with pointy top
function hex(x,y,c)
 for d=-ry,ry do
  local w=flr(hw*min(1,(ry-abs(d))/(ry/2))+.5)
  line(x-w,y+d,x+w,y+d,c)
 end
end

-- cat head. mood: nil sleeping, 1 angry, 2 happy
function cat(x,y,b,mood,r)
 local e,ex,er=max(1,flr(r/2)),flr(r*.7+.5),max(1,flr(r/3))
 local base={9,6,5,7,7,7,15,10}
 circfill(x-ex,y-r-1,er,0) circfill(x+ex,y-r-1,er,0)
 circfill(x,y,r+1,0)
 for d=-r,r do
  local w,l,rr=flr(sqrt(r*r-d*d)+.5),base[b],base[b]
  if b==5 and d<0 then l,rr=5,5 end
  if b==6 then if d<=0 then l,rr=9,5 end end
  line(x-w,y+d,x,y+d,l)
  line(x+1,y+d,x+w,y+d,rr)
 end
 if b==7 then circfill(x,y+e,max(1,flr(r/3)),4) end
 if b==8 then line(x-r+1,y+r,x+r-1,y+r,8) end
 local ec=mood==1 and 8 or b==3 and 10 or 0
 circfill(x-e,y,flr(r/5),ec) circfill(x+e,y,flr(r/5),ec)
 if mood==1 then line(x-e,y+r-1,x+e,y+r-1,8) end
 if mood==2 then pset(x,y+e+1,8) end
end

function blanket(x,y)
 circfill(x,y-ry/3,hr-1,15)
 rectfill(x-hw+1,y,x+hw-1,y+ry-2,13)
 line(x-hw+2,y+1,x+hw-2,y+1,6)
end

function drawgame()
 local f=0
 if b then for k=1,rows*cols do if b.flag[k] then f+=1 end end end
 if over then
  print(over=="win" and "you win! "..fmt(tend).."s"..(newbest and " new best!" or "") or "nyaa! the cat woke up",2,1,over=="win" and 11 or 8)
  print(ncaught.." cats"..(nnew>0 and " ("..nnew.." new)" or "").." o:again x:menu",2,8,7)
 else
  print("cats "..cats-f,2,1,7)
  print("t "..fmt(t0 and time()-t0 or 0),50,1,7)
  print("best "..fmt(dget(lv-1)),88,1,10)
  print(gen and "making a fair board..." or emsg or "o:open x:blanket",2,8,gen and 6 or emsg and 8 or 13)
 end
 for k=1,rows*cols do
  local x,y=ctr(k)
  local o=b and b.open[k]
  local col=o and 15 or 14
  if b and b.flag[k] then col=13 elseif k==cur and not o and not over then col=7 end
  if o and b.cat[k] then col=8 end
  hex(x,y,col)
  if o then
   if b.cat[k] then cat(x,y,b.breed[k],1,hr)
   elseif b.n[k]>0 then print(b.n[k],x-1,y-2,({12,3,8,2,4,1})[b.n[k]]) end
  elseif over and b.cat[k] then cat(x,y,b.breed[k],b.flag[k] and 2,hr)
  elseif b and b.flag[k] then blanket(x,y) end
 end
 if not over then
  local x,y=ctr(cur)
  rect(x-hw,y-ry,x+hw,y+ry,10)
 end
 if mused then circ(stat(32),stat(33),1,0) end
end

function drawtitle()
 ctext("neko mine",8,14)
 cat(64,38,1,nil,13)
 for i=1,3 do
  local y=62+i*10
  print((lv==i and ">" or " ").." "..lvn[i].." "..lvs[i][1].."x"..lvs[i][2],20,y,lv==i and 7 or 13)
  print(fmt(dget(i-1)),100,y,10)
 end
 ctext("up/down:level  o:start",108,6)
 ctext("x:cat dex",116,6)
end

function drawdex()
 local n=0
 for i=1,8 do if dget(2+i)>0 then n+=1 end end
 ctext("cat dex "..n.."/8",4,14)
 local w={30,20,15,15,10,6,3,1}
 for i=1,8 do
  local x,y,c=16+(i-1)%4*32,34+flr((i-1)/4)*44,dget(2+i)
  local star=w[i]>=15 and 1 or w[i]>=6 and 2 or w[i]>=3 and 3 or 4
  if c>0 then
   cat(x,y,i,2,9)
   print(names[i],x-#names[i]*2,y+14,7)
   print(sub("****",1,star),x-star*2,y+21,10)
   print("x"..c,x-#(c.."")*2-2,y+28,13)
  else
   circfill(x,y,10,1)
   print("???",x-6,y+14,5)
   print(sub("****",1,star),x-star*2,y+21,5)
  end
 end
 ctext("o/x:back",118,6)
end

function _draw()
 cls(2)
 if st=="title" then drawtitle() elseif st=="dex" then drawdex() else drawgame() end
end
