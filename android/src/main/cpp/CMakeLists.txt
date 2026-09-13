cmake_minimum_required(VERSION 3.18.1)
project(native_bottomsheet)

add_library(
  native_bottomsheet
  SHARED
  native_bottomsheet.cpp
)

target_link_libraries(
  native_bottomsheet
  android
  log
)
