cmake_minimum_required(VERSION 3.18.1)
project(dartnative_bottom_sheet)

add_library(
  dartnative_bottom_sheet
  SHARED
  dartnative_bottom_sheet.cpp
)

target_link_libraries(
  dartnative_bottom_sheet
  android
  log
)
