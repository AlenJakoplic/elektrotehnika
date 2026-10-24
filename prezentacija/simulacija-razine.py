# Simulacija razine (Elo) za slajd 17 prezentacije: stara i blaža formula (21. 10. 2026.).
# Udjeli studenata na razini 9–10 (11 % i 86 %) na 17. slajdu: N=500 odgovora, 3 000 studenata poznatog znanja.
import random, math, json, statistics as st
def pc(s,q): return 1/3+(2/3)/(1+10**((q-s)/2))
def run(lenient, theta, N, rng):
    r=2.0; n=0; answered=0; wrong=[]; stk=0; traj=[]
    for i in range(N):
        due=[w for w in wrong if w['due']<=answered]
        if due:
            w=due[0]; q=w['q']; qid=w['id']; prev=[x for x in wrong if x['id']==qid]
            wrong=[x for x in wrong if x['id']!=qid]
        else:
            q=min(10,max(1,r+0.8+rng.uniform(-0.4,0.4)+rng.gauss(0,0.3))); qid=rng.random(); prev=[]
        P=pc(r,q); correct=rng.random()<pc(theta,q)
        K=max(0.25,1/math.sqrt(1+n/6)); d=K*((1 if correct else 0)-P)
        if lenient:
            if d<0: d*=0.75
            elif d>0 and correct:
                if prev: d=d*2+sum(x['pen'] for x in prev)
                if stk>=3: d*=1.5
        before=r; r=min(10,max(1,r+d)); n+=1; answered+=1
        stk = stk+1 if correct else 0
        if not correct: wrong.append({'id':qid,'q':q,'due':answered+5+rng.randrange(5),'pen':max(0,before-r)})
        traj.append(r)
    return r,traj
def corr(a,b):
    ma,mb=st.mean(a),st.mean(b); return sum((x-ma)*(y-mb) for x,y in zip(a,b))/math.sqrt(sum((x-ma)**2 for x in a)*sum((y-mb)**2 for y in b))
rng=random.Random(21); N=200; out={}
th=[rng.uniform(1,10) for _ in range(3000)]
for name,len_ in [('stara',False),('blaza',True)]:
    fin=[];tr={}
    for i,t in enumerate(th):
        f,traj=run(len_,t,N,rng); fin.append(f)
    out[name]={'corr':round(corr(th,fin),3),'hist':[sum(1 for f in fin if k<=f<k+1 or (k==9 and f==10)) for k in range(1,10)],
               'top':round(sum(1 for f in fin if f>=9)/len(fin),3),
               'pts':[[round(t,2),round(f,2)] for t,f in list(zip(th,fin))[:300]]}
    # putanje za tri studenta poznatog znanja
    out[name]['traj']={str(t):[round(x,2) for x in run(len_,t,N,random.Random(5))[1][::5]] for t in (3,5,8)}
    print(name,out[name]['corr'],out[name]['top'],out[name]['hist'])
json.dump(out,open('simulacija-rezultat.json','w'))
