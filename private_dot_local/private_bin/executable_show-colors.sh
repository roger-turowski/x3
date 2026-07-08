#!/bin/env bash

# 16 basic colors (foreground and background)
echo "=== Basic 16 Colors ==="
for fgbg in 38 48; do
  for color in {0..15}; do
    printf "\e[${fgbg};5;${color}m%3s\e[0m" "$color"
    # Group by 8
    if (( (color + 1) % 8 == 0 )); then
      echo
    fi
  done
done

# 216-color cube (6x6x6)
echo -e "\n=== 216-Color Cube (16-231) ==="
for green in {0..5}; do
  for red in {0..5}; do
    for blue in {0..5}; do
      color=$((16 + (36 * red) + (6 * green) + blue))
      printf "\e[38;5;${color}m%4d\e[0m" "$color"
    done
    echo
  done
  echo
done

# Grayscale ramp (232-255)
echo "=== Grayscale Ramp (232-255) ==="
for color in {232..255}; do
  printf "\e[38;5;${color}m%4d\e[0m" "$color"
done
echo -e "\n"
