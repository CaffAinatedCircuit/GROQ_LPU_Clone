# GROQ_LPU_Clone
"🎓 Educational RTL to GDS: Plesiochronous circuits & flit sync inspired by Groq LPU concepts. Independent learning design."

## 🚀 How This Whole Thing Started (Real Talk)

Hey there! 👋 Let me be brutally honest - I'm jobless (not "job-less" as a joke, actually zero interviews right now 😅). Been spamming resumes everywhere, which accidentally turned into a masterclass in hardware companies.

I hate studying. Hate reading papers. Need hands-on or I die of boredom ("mens et manus"... wait, I'm not MIT fancy 🥲).

Then boom! Nvidia buying Groq news hits. "Wait, did I apply there?" Googles groq.com → POOF 🤯 Mind = Vaporized.

I've done AI hardware before - systolic arrays? Seen 'em. Near-memory compute? Yawn. But what tf is "plesiochronous"? (Took me 2 hours to spell right... first half of project I called it "plesiosynchronous" 😂 - dinosaur clocking!)

Week 1: Vivado prototype → "This slaps!"
Week 2: Sky130 OpenLane → "Wait, this actually synthesizes?!"

You can try it too! Super easy in Google Colab 📓📓📓:

[📓 Python level Methodology validation and comparison )](notebooks/vivado_sim.ipynb)

[📓 Sky130 Synthesis HAC-SAC deskew]([notebooks/sky130_openlane.ipynb](https://colab.research.google.com/drive/1he1DAnfNCrrmkh2QbLv8vpw9_rFq94wZ#scrollTo=D3PFgCiuYwwf))  

[📓 Sky130 Synthesis Plesiochronous deskew](notebooks/verification.ipynb)

🎪 Me Being Me (ADHD Edition)
Couldn't stick to hardware → Python tradeoff side quest 🐍 (LPU vs GPU token latency plots). Classic me.
📖 What You'll Find Here
This README gives the big picture of LPU/TSP concepts + the 2 modules that makes groq different:
text
✨ plesiochronous circuits with flit synchronization (fixed my dino spelling)
✨ Hardware Aligned Counter and  Software Aligned Counter(custom packets, not Groq's)  
✨ omitted: MAC arrays, tensor schedulers, RISC-V, etc.
Detailed docs/sim/reports in respective readme files each folder - this ain't traditional circuits. Get ready to be GROQIFIED ⚡🧠⚡


```text
Jobless → Curious → Hands dirty → Groq-inspired learning modules
```
You're next! 🚀 Try Colab, get "Groqified", share your version!
## 🎓 MY LEARNING JOURNEY

├── Studied Groq LPU™ public concepts

├── Designed my own plesiochronous circuits

├── Created custom flit sync plesiochronous circuit (just like groq but a bit smaller- synthesizable in colab)

├── Omitted: MAC arrays, tensor scheduler, RISC-V, software

├── 100% FOSS toolchain for GDS Generation

└── Modified for learning differences

## 📄 License
**Unlicense (Public Domain)** - Educational learning exercises only


