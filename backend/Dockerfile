FROM dart:3.14.0 AS build
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN dart pub get --enforce-lockfile
COPY server.dart passkey.dart ./
RUN dart compile exe server.dart -o /server
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /server /server
ENTRYPOINT ["/server"]
