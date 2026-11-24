// Reusable quiz component.
// Markup: <div class="quiz" data-answer="1" data-why="explanation">
//           <p class="q">Question</p><button>opt0</button><button>opt1</button>...
//         </div>
// data-answer is the 0-based index of the correct button.
(function(){
  const css = `.quiz{background:var(--card);border-radius:6px;padding:1rem 1.1rem;margin:1.2rem 0}
  .quiz .q{margin:0 0 .6rem;font-weight:600}
  .quiz button{display:block;width:100%;text-align:left;font:inherit;font-size:.95rem;margin:.35rem 0;
    padding:.5rem .7rem;border:1px solid var(--rule);border-radius:4px;background:var(--bg);color:var(--fg);cursor:pointer}
  .quiz button.right{border-color:var(--ok);color:var(--ok)}
  .quiz button.wrong{border-color:var(--bad);color:var(--bad);text-decoration:line-through}
  .quiz .why{font-size:.9rem;margin-top:.6rem}
  .quiz-score{font-style:italic;color:var(--muted)}`;
  const s=document.createElement('style'); s.textContent=css; document.head.appendChild(s);
  let answered=0, first=0;
  const quizzes=[...document.querySelectorAll('.quiz')];
  const score=document.querySelector('.quiz-score');
  quizzes.forEach(qz=>{
    const ans=+qz.dataset.answer, btns=[...qz.querySelectorAll('button')];
    let tried=false;
    btns.forEach((b,i)=>b.addEventListener('click',()=>{
      if(qz.dataset.done) return;
      if(i===ans){
        b.classList.add('right'); qz.dataset.done=1; answered++; if(!tried) first++;
        const w=document.createElement('p'); w.className='why'; w.innerHTML=qz.dataset.why; qz.appendChild(w);
        if(score && answered===quizzes.length) score.textContent=`${first} of ${quizzes.length} right on the first try.`;
      } else { b.classList.add('wrong'); tried=true; }
    }));
  });
})();
