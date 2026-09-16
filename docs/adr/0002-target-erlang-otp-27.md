# Target Erlang/OTP 27

We standardize on Erlang/OTP 27 as the primary supported runtime. It is the
current maintained release, and committing to it lets us drop compatibility
shims for ancient OTP versions and use modern language and runtime features. The
accepted trade-off is that the codebase will not build or run on the old OTP
releases earlier Kazoo deployments relied on.
