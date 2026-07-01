/// Evaluador puro de expresiones de calculadora.
/// Soporta: + − × ÷, % (porcentaje del acumulado), paréntesis, decimales, signo +/−.
/// Devuelve "Error" ante división por cero, paréntesis desbalanceados o token inválido.
/// Sin dependencias externas; se puede replicar en Kotlin (CalculatorEngine).
library;

class CalculatorEngine {
  static String evaluate(String expr) {
    if (expr.trim().isEmpty) return '';
    try {
      final tokens = _tokenize(expr.trim());
      if (tokens.isEmpty) return '';
      final result = _parseExpr(tokens, 0);
      if (result.pos != tokens.length) return 'Error';
      final v = result.value;
      if (v.isNaN || v.isInfinite) return 'Error';
      // Formatea: sin decimal innecesario
      if (v == v.truncateToDouble()) {
        final i = v.toInt();
        return i.toString();
      }
      // Hasta 10 dígitos significativos, sin trailing zeros
      String s = v.toStringAsFixed(10);
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
      return s;
    } catch (_) {
      return 'Error';
    }
  }

  // ===== Tokenizer =====

  static List<_Token> _tokenize(String expr) {
    final tokens = <_Token>[];
    int i = 0;
    while (i < expr.length) {
      final ch = expr[i];
      if (ch == ' ') { i++; continue; }
      if (_isDigit(ch) || ch == '.') {
        final start = i;
        while (i < expr.length && (_isDigit(expr[i]) || expr[i] == '.')) { i++; }
        tokens.add(_Token(_TType.number, double.parse(expr.substring(start, i))));
        continue;
      }
      if (ch == '+') { tokens.add(_Token(_TType.plus)); i++; continue; }
      if (ch == '-' || ch == '−') { tokens.add(_Token(_TType.minus)); i++; continue; }
      if (ch == '*' || ch == '×') { tokens.add(_Token(_TType.mul)); i++; continue; }
      if (ch == '/' || ch == '÷') { tokens.add(_Token(_TType.div)); i++; continue; }
      if (ch == '%') { tokens.add(_Token(_TType.percent)); i++; continue; }
      if (ch == '(') { tokens.add(_Token(_TType.lparen)); i++; continue; }
      if (ch == ')') { tokens.add(_Token(_TType.rparen)); i++; continue; }
      throw Exception('token inválido: $ch');
    }
    return tokens;
  }

  static bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

  // ===== Parser recursivo descendente =====
  // expr   → term (('+' | '−') term)*
  // term   → unary (('×' | '÷' | '%') unary)*
  // unary  → '−' unary | primary
  // primary → NUMBER | '(' expr ')'

  static _Result _parseExpr(List<_Token> t, int pos) {
    var res = _parseTerm(t, pos);
    while (res.pos < t.length &&
        (t[res.pos].type == _TType.plus || t[res.pos].type == _TType.minus)) {
      final op = t[res.pos].type;
      final right = _parseTerm(t, res.pos + 1);
      res = _Result(
        op == _TType.plus ? res.value + right.value : res.value - right.value,
        right.pos,
      );
    }
    return res;
  }

  static _Result _parseTerm(List<_Token> t, int pos) {
    var res = _parseUnary(t, pos);
    while (res.pos < t.length &&
        (t[res.pos].type == _TType.mul ||
            t[res.pos].type == _TType.div ||
            t[res.pos].type == _TType.percent)) {
      final op = t[res.pos].type;
      final right = _parseUnary(t, res.pos + 1);
      double v;
      if (op == _TType.mul) {
        v = res.value * right.value;
      } else if (op == _TType.div) {
        if (right.value == 0) throw Exception('div/0');
        v = res.value / right.value;
      } else {
        // %: el operando izquierdo como porcentaje del acumulado
        // ej. 200 + 10% = 200 + 200*0.10 = 220
        // En término aislado: 50% = 0.5
        v = res.value * (right.value / 100.0);
      }
      res = _Result(v, right.pos);
    }
    return res;
  }

  static _Result _parseUnary(List<_Token> t, int pos) {
    if (pos < t.length && t[pos].type == _TType.minus) {
      final inner = _parseUnary(t, pos + 1);
      return _Result(-inner.value, inner.pos);
    }
    if (pos < t.length && t[pos].type == _TType.plus) {
      return _parseUnary(t, pos + 1);
    }
    return _parsePrimary(t, pos);
  }

  static _Result _parsePrimary(List<_Token> t, int pos) {
    if (pos >= t.length) throw Exception('fin inesperado');
    if (t[pos].type == _TType.number) {
      return _Result(t[pos].value!, pos + 1);
    }
    if (t[pos].type == _TType.lparen) {
      final inner = _parseExpr(t, pos + 1);
      if (inner.pos >= t.length || t[inner.pos].type != _TType.rparen) {
        throw Exception('paréntesis sin cerrar');
      }
      return _Result(inner.value, inner.pos + 1);
    }
    throw Exception('token inesperado: ${t[pos].type}');
  }
}

enum _TType { number, plus, minus, mul, div, percent, lparen, rparen }

class _Token {
  final _TType type;
  final double? value;
  _Token(this.type, [this.value]);
}

class _Result {
  final double value;
  final int pos;
  _Result(this.value, this.pos);
}
