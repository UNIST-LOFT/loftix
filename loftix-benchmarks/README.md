## sdfuzz

```bash
cd loftix-benchmarks/binutils/CVE-2017-14940
bash sdfuzz.sh all
```
sdfuzz.sh all runs:
1. prepare: get the source code from guix
2. stack: ASan binary is built and   executed with the crash input to get the stack trace
3. pass1: LTO build with BB instrumentation pass, extract BBnames.txt, BBcalls.txt, IIcalls.txt
4. analyze: run getnDistance.sh to produce distance.cfg.txt
5. pass2: Distance instrumented binary is built

After pass2, you can run the fuzzer with the distance instrumented binary. ```bash
bash sdfuzz.sh fuzz
```