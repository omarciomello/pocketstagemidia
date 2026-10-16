#pragma once
#include <flutter/binary_messenger.h>
#include <windows.h>

// Canal "psm/janela" da janela do telão: põe a janela no monitor do telão, sem borda.
void PsmJanelaRegistrar(flutter::BinaryMessenger* messenger, HWND view);
