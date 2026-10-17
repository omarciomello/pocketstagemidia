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

/// Atalho de linha: as teclas 1 a 9 (e 0 = linha 10) tocam a linha inteira.
class RowKeyAction extends KeyAction {
  const RowKeyAction(this.row);
  final int row;
}

/// Linha (0 em diante) que a tecla [name] toca, ou null.
int? rowOfKey(String name, Show show) {
  if (name.length != 1) return null;
  final d = int.tryParse(name);
  if (d == null) return null;
  final row = d == 0 ? 9 : d - 1;
  return row < show.rows ? row : null;
}

/// Tecla da linha [row] (0 em diante), ou null acima da linha 10.
String? keyOfRow(int row) => row < 9 ? '${row + 1}' : (row == 9 ? '0' : null);

/// Resolve a tecla [name]. Atalho geral vence atalho de mídia, que vence atalho de linha. null = nada.
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
  final row = rowOfKey(name, show);
  return row == null ? null : RowKeyAction(row);
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
    final row = rowOfKey(name, show);
    if (row != null) return 'Linha ${row + 1}';
  }
  return null;
}
