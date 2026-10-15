import 'model.dart';

/// O que uma tecla (teclado ou pedal) faz na tela do show.
sealed class KeyAction {
  const KeyAction();
}

/// Atalho geral (GO, linha anterior, Parar tudo, Pausar, Apagar telão).
class GlobalKeyAction extends KeyAction {
  const GlobalKeyAction(this.key);
  final ShortcutAction key;
}

/// Atalho de uma mídia.
class CueKeyAction extends KeyAction {
  const CueKeyAction(this.cueId);
  final String cueId;
}

/// Resolve a tecla [name]. Atalho geral vence atalho de mídia. null = nada.
KeyAction? resolveKey(String name, Settings settings, Show? show) {
  if (name.isEmpty) return null;
  for (final g in ShortcutAction.values) {
    if (settings.key(g) == name) return GlobalKeyAction(g);
  }
  if (show == null) return null;
  for (var i = 0; i < show.count; i++) {
    final c = show.cells[i];
    if (c != null && c.hotkey == name) return CueKeyAction(c.id);
  }
  return null;
}

/// Nomes amigáveis das teclas especiais.
String keyLabel(String k) => const {
      'Space': 'Espaço',
      'Enter': 'Enter',
      'PageUp': 'PgUp',
      'PageDown': 'PgDn',
      'ArrowUp': '↑',
      'ArrowDown': '↓',
      'ArrowLeft': '←',
      'ArrowRight': '→',
    }[k] ??
    k;

/// Teclas já usadas por atalhos gerais ou por outras mídias (para avisar conflito ao editar).
/// Retorna a descrição de quem já usa [name], ou null se estiver livre.
String? keyConflict(String name, Settings settings, Show? show, {String? exceptCueId, ShortcutAction? exceptGlobal}) {
  if (name.isEmpty) return null;
  for (final g in ShortcutAction.values) {
    if (g != exceptGlobal && settings.key(g) == name) return g.label;
  }
  if (show != null) {
    for (var i = 0; i < show.count; i++) {
      final c = show.cells[i];
      if (c != null && c.id != exceptCueId && c.hotkey == name) return c.name;
    }
  }
  return null;
}
