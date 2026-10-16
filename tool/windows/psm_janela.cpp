#include "psm_janela.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <vector>

namespace {

std::vector<std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>> g_canais;

BOOL CALLBACK Juntar(HMONITOR m, HDC, LPRECT, LPARAM p) {
  reinterpret_cast<std::vector<HMONITOR>*>(p)->push_back(m);
  return TRUE;
}

// Monitor do telão: o primeiro que não é o principal; sem segundo monitor, o principal.
bool MonitorDoTelao(RECT* r) {
  std::vector<HMONITOR> mons;
  EnumDisplayMonitors(nullptr, nullptr, Juntar, reinterpret_cast<LPARAM>(&mons));
  MONITORINFO escolhido{};
  bool achou = false;
  for (HMONITOR m : mons) {
    MONITORINFO mi{};
    mi.cbSize = sizeof(mi);
    if (!GetMonitorInfo(m, &mi)) continue;
    if (!(mi.dwFlags & MONITORINFOF_PRIMARY)) {
      escolhido = mi;
      achou = true;
      break;
    }
    if (!achou) {
      escolhido = mi;
    }
  }
  if (mons.empty()) return false;
  *r = escolhido.rcMonitor;
  return true;
}

}  // namespace

void PsmJanelaRegistrar(flutter::BinaryMessenger* messenger, HWND view) {
  auto canal = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "psm/janela", &flutter::StandardMethodCodec::GetInstance());
  canal->SetMethodCallHandler(
      [view](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        HWND janela = GetAncestor(view, GA_ROOT);
        if (janela == nullptr) {
          result->Error("sem_janela", "Janela do telão não encontrada.");
          return;
        }
        if (call.method_name() == "fechar") {
          PostMessage(janela, WM_CLOSE, 0, 0);
          result->Success();
          return;
        }
        RECT r{};
        if (!MonitorDoTelao(&r)) {
          result->Error("sem_monitor", "Nenhum monitor encontrado.");
          return;
        }
        const int w = r.right - r.left;
        const int h = r.bottom - r.top;
        if (call.method_name() == "entrar") {
          // Passo 1: janela sem borda, pequena e inteira dentro do monitor do telão
          // (o Windows ajusta a escala uma vez só, sem a janela ficar entre dois monitores).
          LONG_PTR st = GetWindowLongPtr(janela, GWL_STYLE);
          st = (st & ~static_cast<LONG_PTR>(WS_OVERLAPPEDWINDOW)) | WS_POPUP;
          SetWindowLongPtr(janela, GWL_STYLE, st);
          SetWindowPos(janela, HWND_TOP, r.left + w / 4, r.top + h / 4, w / 2, h / 2,
                       SWP_FRAMECHANGED | SWP_NOACTIVATE | SWP_SHOWWINDOW);
          result->Success(flutter::EncodableValue(std::to_string(w) + "×" + std::to_string(h)));
        } else if (call.method_name() == "ocupar") {
          // Passo 2: ocupa o monitor inteiro.
          SetWindowPos(janela, HWND_TOP, r.left, r.top, w, h,
                       SWP_FRAMECHANGED | SWP_NOACTIVATE | SWP_SHOWWINDOW);
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
  g_canais.push_back(std::move(canal));
}
