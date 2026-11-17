cmake_minimum_required(VERSION 3.18.1)
project(native_bottomsheet)

add_library(
  native_bottomsheet
  SHARED
  dartnative_bottom_sheet.cpp
)

target_link_libraries(
  native_bottomsheet
  android
  log
)
