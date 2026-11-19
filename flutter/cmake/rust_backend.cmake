# The native library is built as part of the Flutter build, never copied from a
# developer-specific installation. It links the existing Rust workspace only.
find_program(KIYORA_CARGO cargo REQUIRED)
get_filename_component(KIYORA_WORKSPACE "${CMAKE_CURRENT_LIST_DIR}/../../src-tauri" ABSOLUTE)
set(KIYORA_CARGO_TARGET "${KIYORA_WORKSPACE}/target")
set(KIYORA_RUST_PROFILE "$<IF:$<CONFIG:Debug>,debug,release>")
set(KIYORA_RELEASE_FLAG "$<$<NOT:$<CONFIG:Debug>>:--release>")
if(WIN32)
  set(KIYORA_RUST_LIBRARY "kiyora_flutter_bridge.dll")
else()
  set(KIYORA_RUST_LIBRARY "libkiyora_flutter_bridge.so")
endif()
add_custom_target(kiyora_rust_backend ALL
  COMMAND ${CMAKE_COMMAND} -E env "CARGO_TARGET_DIR=${KIYORA_CARGO_TARGET}"
    ${KIYORA_CARGO} build --locked --manifest-path "${KIYORA_WORKSPACE}/Cargo.toml"
    -p kiyora-flutter-bridge ${KIYORA_RELEASE_FLAG}
  BYPRODUCTS "${KIYORA_CARGO_TARGET}/${KIYORA_RUST_PROFILE}/${KIYORA_RUST_LIBRARY}"
  COMMAND_EXPAND_LISTS VERBATIM)
add_dependencies(${BINARY_NAME} kiyora_rust_backend)
install(FILES "${KIYORA_CARGO_TARGET}/${KIYORA_RUST_PROFILE}/${KIYORA_RUST_LIBRARY}"
  DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)
