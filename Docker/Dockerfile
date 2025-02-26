ARG swift_version="6.0"
ARG build_mode="release"

# build sm-eda executable ------------------------------------------------------
FROM swift:$swift_version AS swift-builder
ARG build_mode

ADD . /repo

# build sm-eda using swift
RUN cd repo && swift build -c $build_mode --static-swift-stdlib
# copy license
RUN mkdir /sm-eda && mkdir /sm-eda/bin && mkdir /sm-eda/bash
RUN cp /repo/LICENSE /sm-eda/LICENSE
# copy binary artifacts
RUN cd repo && find $(swift build -c $build_mode --show-bin-path) -type f -executable -exec cp {} /sm-eda/bin ";"
RUN cd sm-eda && find bin -type f -executable -exec bash -c '{} --generate-completion-script bash > bash/$(basename {}).sh' ";"

# build yosys and yosys-abc executable -----------------------------------------
FROM ubuntu:latest AS yosys-builder

ADD /Docker /Docker
RUN bash /Docker/build-yosys.bash

# setup base image -------------------------------------------------------------
FROM ubuntu:latest AS base
ADD /Docker/setup-run-deps.bash /
RUN bash setup-run-deps.bash && rm setup-run-deps.bash

# build production image -------------------------------------------------------
FROM base
# add artifacts from builder
COPY --from=swift-builder /sm-eda /opt/sm-eda
COPY --from=swift-builder /repo/Resources/Flow /flow
COPY --from=yosys-builder /yosys /opt/yosys
RUN find /opt/sm-eda/bash -name "*.sh" -exec bash -c 'echo "source {}" >> /root/.bashrc' ";"
# set path
ENV PATH="${PATH}:/opt/sm-eda/bin:/opt/yosys/bin"
