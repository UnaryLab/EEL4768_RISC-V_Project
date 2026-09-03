# Phase 1 Documentation

You will find the documentation and problem descriptions for phase one in `phase_1/documentation/phase_1.pdf`. Be sure to **read all pages** of the PDF. There are two parts to this phase, that break down as follows.

1. RISC-V Assembly

    1.1 Multiplication

    1.2 General Matrix Multiplication

    1.3 Sobel Filter
    
2. RISC-V Assembler

# Phase 1 self-check

This docker file exists to aid students in validating their phase 1 results before submitting for a grade.

This does not include all test cases, and it is up to the students to fully validate the functionality of their code.

Either a linux environment or docker is required.

## Put your files here

```
phase_1/submission/
    assembler.py
    addition.s
    gemm.s
    mult.s
    sobel.s
```

## Run it with Docker

Build the image once, and rebuild it whenever you pull an update to this
repository -- the checker and the expected outputs are baked into the image:

```
docker build -t phase1-check phase_1
```

Then run it after every edit to your files:

```
docker run --rm -v "$PWD/phase_1/submission:/work/submission" phase1-check:latest
```

## Run it without Docker

Needs `python3` and `java` on your PATH:

```
./phase_1/run_test.sh mycheck
```

Pass a directory as a second argument to check files kept somewhere other than
`phase_1/submission/`.

## Reading the output

One line per check, then a total:

```
PASS  Assembly:  gemm (config 1)
FAIL  Assembly:  mult (config 1)  --  result memory differs from the expected ...
...
5/6 PASS
```

A FAIL line ends with the reason. The command exits 0 only when all six pass.

Outside Docker, the summary is also written to `phase_1/results/<name>.txt`, and
what each check produced -- the program it ran, the RARS memory dump, and the
files your assembler generated -- is left in `phase_1/output/` for you to
inspect.

## Sobel: two accepted answers

The handout left the last step of the Sobel filter ambiguous, so **both**
readings pass the `sobel` check:

- `c[i][j] = gx[i][j] + gy[i][j]`, the sum the handout writes out, and
- `c[i][j] = gx[i][j]^2 + gy[i][j]^2`, the squared gradient magnitude.

Either way, use the kernel values from the `.data` section exactly as given.
A FAIL line for `sobel` is measured against whichever of the two your output
came closer to.
