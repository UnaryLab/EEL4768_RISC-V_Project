# An image whose only job is running phase_1/run_test.sh.
#
# The whole dependency set, taken from source_test/:
#   openjdk-17-jre-headless  runs source_test/rars1_6.jar
#   python3                  runs run_test.sh's checker and the student's
#                            assembler.py
# Nothing else: the checker imports only the standard library, and so does the
# assembler students are asked to write.
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        openjdk-17-jre-headless \
        python3 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /work
# The checker, the RARS jar, the configuration .data blocks and the expected
# outputs (including sobel's two accepted answers) are all baked in here, so
# the image has to be rebuilt after every update to this repository.
COPY . /work/

# run_test.sh writes results/ and output/ under /work, so the tree has to be
# writable by whoever runs it.
CMD ["./run_test.sh", "selftest"]
