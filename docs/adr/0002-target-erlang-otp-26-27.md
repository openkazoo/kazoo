# Target Erlang/OTP 26 and 27

We standardize on Erlang/OTP 26 and 27 as the supported runtimes. They are the
current maintained releases, and committing to them lets us drop compatibility
shims for ancient OTP versions and use modern language and runtime features. The
accepted trade-off is that the codebase will not build or run on the old OTP
releases earlier Kazoo deployments relied on.
