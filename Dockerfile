FROM maven:3-jdk-11
# debian based

ARG ANDROID_COMMAND_LINE_TOOLS_SHA256_SUM=124f2d5115eee365df6cf3228ffbca6fc3911d16f8025bebd5b1c6e2fcfa7faf
ARG ANDROID_COMMAND_LINE_TOOLS_VERSION=7583922_latest

ARG ANDROID_API_VERSION=30
ARG ANDROID_BUILD_TOOLS_VERSION=30.0.3

ENV JAVA_OPTS "-Xms512m -Xmx1024m"
ENV ANDROID_SDK_ROOT=/var/android-sdk

USER root

RUN apt-get update  \
    && apt-get install -y unzip wget jq moreutils qemu-kvm libvirt-dev virtinst bridge-utils cpu-checker unzip wget tree && \
    mkdir -p ${ANDROID_SDK_ROOT} && \
    # get android command line tools
    wget https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_COMMAND_LINE_TOOLS_VERSION}.zip -O commandlinetools-linux.zip && \
    echo "${ANDROID_COMMAND_LINE_TOOLS_SHA256_SUM} commandlinetools-linux.zip" | sha256sum -c - && \
    unzip commandlinetools-linux.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools && \
    mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest && \
    ln -s ${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/avdmanager /usr/local/bin && \
    ln -s ${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager /usr/local/bin && \
    (yes | sdkmanager --licenses) && \
    sdkmanager "emulator" "platform-tools" && \
    ln -s ${ANDROID_SDK_ROOT}/emulator/emulator /usr/local/bin && \
    ln -s ${ANDROID_SDK_ROOT}/platform-tools/adb /usr/local/bin && \
    yes | sdkmanager --sdk_root=${ANDROID_SDK_ROOT} "extras;google;google_play_services" "tools" "platforms;android-30" "build-tools;${ANDROID_BUILD_TOOLS_VERSION}" && \
    rm commandlinetools-linux.zip && \
    echo "5 4 * * * /usr/bin/find /tmp/android* -mtime +3 -exec rm -rf {} \;" > ${ANDROID_SDK_ROOT}/cleanup.cron && \
    # cleanup and get runtime dependencies
    apt-get remove -y unzip wget && apt-get auto-remove -y && \
    apt-get install -y libfontconfig libglu1 libnss3-dev libxcomposite1 libxcursor1 libpulse0 libasound2 socat && \
    rm -rf /var/lib/apt/lists/*

# Create emulators
RUN sdkmanager "platforms;android-30" "system-images;android-${ANDROID_API_VERSION};google_apis;x86_64" \
    && rm ${ANDROID_SDK_ROOT}/emulator/qemu/linux-x86_64/qemu-system-aarch64* \
    && rm ${ANDROID_SDK_ROOT}/emulator/qemu/linux-x86_64/qemu-system-armel*  \
    && rm ${ANDROID_SDK_ROOT}/emulator/qemu/linux-x86_64/qemu-system-i386*  \
    && echo no | avdmanager create avd -n "Pixel_2" --package "system-images;android-${ANDROID_API_VERSION};google_apis;x86_64" \
    && echo no | avdmanager create avd -n "Nexus_6" --package "system-images;android-${ANDROID_API_VERSION};google_apis;x86_64"

#====================================
# Install latest nodejs, npm, appium
#====================================
ARG NODE_VERSION=v14.19.0
ENV NODE_VERSION=$NODE_VERSION
ARG APPIUM_VERSION=1.22.2
ENV APPIUM_VERSION=$APPIUM_VERSION

# install appium
RUN apt-get update  \
    && apt-get install -y unzip wget tree \
    && wget -q https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-x64.tar.xz \
    && tar -xJf node-${NODE_VERSION}-linux-x64.tar.xz -C /opt/ \
    && ln -s /opt/node-${NODE_VERSION}-linux-x64/bin/npm /usr/bin/ \
    && ln -s /opt/node-${NODE_VERSION}-linux-x64/bin/node /usr/bin/ \
    && ln -s /opt/node-${NODE_VERSION}-linux-x64/bin/npx /usr/bin/ \
    && npm install -g appium@1.22.3 --allow-root --unsafe-perm=true \
    && npm install -g appium-doctor --allow-root --unsafe-perm=true \
    && npm install -g allure-commandline \
    && ln -s /opt/node-${NODE_VERSION}-linux-x64/bin/appium /usr/bin/ \
    && ln -s /opt/node-${NODE_VERSION}-linux-x64/bin/allure /usr/bin/

HEALTHCHECK CMD \[ $(adb shell getprop sys.boot_completed) \] || exit 1

EXPOSE 4723 4724 4725 2251 5555 5554

CMD ["emulator", "Nexus_6", "-use-system-libs", "-read-only", "-no-boot-anim", "-no-window", "-no-audio", "-no-snapstorage", "-verbose"]
CMD ["emulator", "Pixel_2", "-use-system-libs", "-read-only", "-no-boot-anim", "-no-window", "-no-audio", "-no-snapstorage", "-verbose"]
CMD ["sh", "adb", "devices"]
