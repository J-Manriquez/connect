package com.example.connect

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.os.Build
import android.util.Base64
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject

class CalculatorWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) render(context, appWidgetManager, id)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val ui = context.getSharedPreferences(PREFS_UI, Context.MODE_PRIVATE).edit()
        for (id in appWidgetIds) {
            ui.remove("expr_$id").remove("display_$id")
                .remove("evaluated_$id").remove("mode_$id").remove("hoff_$id")
        }
        ui.apply()
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val id = intent.getIntExtra(EXTRA_WIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        if (id == AppWidgetManager.INVALID_APPWIDGET_ID) return
        val mgr = AppWidgetManager.getInstance(context)
        val ui = context.getSharedPreferences(PREFS_UI, Context.MODE_PRIVATE)

        when (intent.action) {
            ACTION_KEY -> {
                val key = intent.getStringExtra(EXTRA_KEY) ?: return
                handleKey(context, ui, id, key)
                render(context, mgr, id)
            }
            ACTION_TOGGLE_HISTORY -> {
                val cur = ui.getInt("mode_$id", MODE_KEYPAD)
                val next = if (cur == MODE_HISTORY) MODE_KEYPAD else MODE_HISTORY
                ui.edit().putInt("mode_$id", next).apply()
                render(context, mgr, id)
            }
            ACTION_HIST_UP -> {
                val cur = ui.getInt("hoff_$id", 0)
                if (cur > 0) ui.edit().putInt("hoff_$id", cur - 1).apply()
                render(context, mgr, id)
            }
            ACTION_HIST_DOWN -> {
                val count = historyCount(context)
                val cur = ui.getInt("hoff_$id", 0)
                if (cur < count - HIST_ROWS) ui.edit().putInt("hoff_$id", cur + 1).apply()
                render(context, mgr, id)
            }
            ACTION_LOAD_HIST -> {
                val result = intent.getStringExtra(EXTRA_HIST_RESULT) ?: return
                val edit = ui.edit()
                edit.putString("expr_$id", result)
                edit.putString("display_$id", result)
                edit.putBoolean("evaluated_$id", true)
                edit.putInt("mode_$id", MODE_KEYPAD)
                edit.apply()
                render(context, mgr, id)
            }
        }
    }

    companion object {
        private const val PREFS_FLUTTER = "FlutterSharedPreferences"
        private const val PREFS_UI = "calc_widget_ui"
        private const val KEY_HISTORY = "flutter.calc_history_json"

        private const val ACTION_PREFIX = "com.example.connect.widget.CALC"
        const val ACTION_KEY = "$ACTION_PREFIX.KEY"
        const val ACTION_TOGGLE_HISTORY = "$ACTION_PREFIX.TOGGLE_HISTORY"
        const val ACTION_HIST_UP = "$ACTION_PREFIX.HIST_UP"
        const val ACTION_HIST_DOWN = "$ACTION_PREFIX.HIST_DOWN"
        const val ACTION_LOAD_HIST = "$ACTION_PREFIX.LOAD_HIST"

        private const val EXTRA_WIDGET_ID = "appWidgetId"
        private const val EXTRA_KEY = "key"
        private const val EXTRA_HIST_RESULT = "histResult"

        private const val MODE_KEYPAD = 0
        private const val MODE_HISTORY = 2
        private const val HIST_ROWS = 3

        // ── Defaults espejo de CalculatorStyleService.def* ──────────────────
        private const val DEF_BG_ARGB           = 0xFF1C1C1E.toInt()
        private const val DEF_BG_ALPHA          = 255
        private const val DEF_BORDER_RADIUS      = 20
        private const val DEF_DISPLAY_BG_ARGB   = 0xFF2C2C2E.toInt()
        private const val DEF_DISPLAY_RADIUS     = 12
        private const val DEF_EXPR_COLOR         = 0xFFAAAAAA.toInt()
        private const val DEF_EXPR_SP            = 22
        private const val DEF_RESULT_COLOR       = 0xFFFFFFFF.toInt()
        private const val DEF_RESULT_SP          = 40
        private const val DEF_NUM_BG             = 0xFF3A3A3C.toInt()
        private const val DEF_NUM_FG             = 0xFFFFFFFF.toInt()
        private const val DEF_NUM_SP             = 26
        private const val DEF_NUM_RADIUS         = 12
        private const val DEF_OP_BG              = 0xFFFF9F0A.toInt()
        private const val DEF_OP_FG              = 0xFFFFFFFF.toInt()
        private const val DEF_OP_SP              = 28
        private const val DEF_OP_RADIUS          = 12
        private const val DEF_FN_BG              = 0xFF636366.toInt()
        private const val DEF_FN_FG              = 0xFFFFFFFF.toInt()
        private const val DEF_FN_SP              = 22
        private const val DEF_FN_RADIUS          = 12
        private const val DEF_EQ_BG              = 0xFFFF9F0A.toInt()
        private const val DEF_EQ_FG              = 0xFFFFFFFF.toInt()
        private const val DEF_EQ_SP              = 30
        private const val DEF_EQ_RADIUS          = 12
        private const val DEF_BTN_SPACING        = 10
        private const val DEF_KEYPAD_PADDING     = 12
        private const val DEF_SCALE_PCT          = 100
        private const val DEF_HIST_RADIUS        = 8

        // ── Config ──────────────────────────────────────────────────────────
        private data class CalcCfg(
            val bgArgb: Int, val bgAlpha: Int, val borderRadius: Int,
            val displayBgArgb: Int, val displayRadius: Int,
            val exprColor: Int, val exprSp: Float,
            val resultColor: Int, val resultSp: Float,
            val numBg: Int, val numFg: Int, val numSp: Float, val numRadius: Int,
            val opBg: Int, val opFg: Int, val opSp: Float, val opRadius: Int,
            val fnBg: Int, val fnFg: Int, val fnSp: Float, val fnRadius: Int,
            val eqBg: Int, val eqFg: Int, val eqSp: Float, val eqRadius: Int,
            val btnSpacing: Int, val keypadPadding: Int, val scale: Float,
            val histRadius: Int,
            val iconEquals: String, val iconBackspace: String,
            val iconHistory: String
        )

        private fun readCalcCfg(prefs: android.content.SharedPreferences): CalcCfg {
            val pf = "flutter.widget_cfg_calc_"
            val scale = fInt(prefs, pf + "content_scale_pct", DEF_SCALE_PCT).coerceIn(50, 200) / 100f
            return CalcCfg(
                bgArgb        = fColor(prefs, pf + "bg_argb",           DEF_BG_ARGB),
                bgAlpha       = fInt(prefs, pf + "bg_alpha",            DEF_BG_ALPHA).coerceIn(0, 255),
                borderRadius  = fInt(prefs, pf + "border_radius",       DEF_BORDER_RADIUS).coerceIn(0, 48),
                displayBgArgb = fColor(prefs, pf + "display_bg_argb",   DEF_DISPLAY_BG_ARGB),
                displayRadius = fInt(prefs, pf + "display_radius",      DEF_DISPLAY_RADIUS).coerceIn(0, 32),
                exprColor     = fColor(prefs, pf + "expr_color",        DEF_EXPR_COLOR),
                exprSp        = fInt(prefs, pf + "expr_size_sp",        DEF_EXPR_SP).coerceIn(10, 50) * scale,
                resultColor   = fColor(prefs, pf + "result_color",      DEF_RESULT_COLOR),
                resultSp      = fInt(prefs, pf + "result_size_sp",      DEF_RESULT_SP).coerceIn(16, 72) * scale,
                numBg         = fColor(prefs, pf + "num_bg_argb",       DEF_NUM_BG),
                numFg         = fColor(prefs, pf + "num_text_color",    DEF_NUM_FG),
                numSp         = fInt(prefs, pf + "num_text_size_sp",    DEF_NUM_SP).coerceIn(10, 50) * scale,
                numRadius     = fInt(prefs, pf + "num_radius",          DEF_NUM_RADIUS).coerceIn(0, 32),
                opBg          = fColor(prefs, pf + "op_bg_argb",        DEF_OP_BG),
                opFg          = fColor(prefs, pf + "op_text_color",     DEF_OP_FG),
                opSp          = fInt(prefs, pf + "op_text_size_sp",     DEF_OP_SP).coerceIn(10, 50) * scale,
                opRadius      = fInt(prefs, pf + "op_radius",           DEF_OP_RADIUS).coerceIn(0, 32),
                fnBg          = fColor(prefs, pf + "fn_bg_argb",        DEF_FN_BG),
                fnFg          = fColor(prefs, pf + "fn_text_color",     DEF_FN_FG),
                fnSp          = fInt(prefs, pf + "fn_text_size_sp",     DEF_FN_SP).coerceIn(10, 50) * scale,
                fnRadius      = fInt(prefs, pf + "fn_radius",           DEF_FN_RADIUS).coerceIn(0, 32),
                eqBg          = fColor(prefs, pf + "eq_bg_argb",        DEF_EQ_BG),
                eqFg          = fColor(prefs, pf + "eq_text_color",     DEF_EQ_FG),
                eqSp          = fInt(prefs, pf + "eq_text_size_sp",     DEF_EQ_SP).coerceIn(10, 50) * scale,
                eqRadius      = fInt(prefs, pf + "eq_radius",           DEF_EQ_RADIUS).coerceIn(0, 32),
                btnSpacing    = (fInt(prefs, pf + "btn_spacing_dp",    DEF_BTN_SPACING) * scale).toInt(),
                keypadPadding = (fInt(prefs, pf + "keypad_padding_dp", DEF_KEYPAD_PADDING) * scale).toInt(),
                scale         = scale,
                histRadius    = fInt(prefs, pf + "hist_radius",        DEF_HIST_RADIUS).coerceIn(0, 32),
                iconEquals    = fStr(prefs, pf + "icon_equals_b64"),
                iconBackspace = fStr(prefs, pf + "icon_backspace_b64"),
                iconHistory   = fStr(prefs, pf + "icon_history_b64")
            )
        }

        // ── Evaluador espejo del Dart CalculatorEngine ───────────────────────

        fun evaluate(expr: String): String {
            if (expr.isBlank()) return ""
            return try {
                val tokens = tokenize(expr.trim())
                if (tokens.isEmpty()) return ""
                val (v, pos) = parseExpr(tokens, 0)
                if (pos != tokens.size) return "Error"
                if (v.isNaN() || v.isInfinite()) return "Error"
                if (v == kotlin.math.floor(v) && !v.isInfinite()) {
                    v.toLong().toString()
                } else {
                    val s = "%.10f".format(v)
                    s.trimEnd('0').trimEnd('.')
                }
            } catch (_: Exception) {
                "Error"
            }
        }

        private enum class TType { NUMBER, PLUS, MINUS, MUL, DIV, PERCENT, LPAREN, RPAREN }
        private data class Token(val type: TType, val value: Double = 0.0)

        private fun tokenize(expr: String): List<Token> {
            val tokens = mutableListOf<Token>()
            var i = 0
            while (i < expr.length) {
                val ch = expr[i]
                if (ch == ' ') { i++; continue }
                if (ch.isDigit() || ch == '.') {
                    val start = i
                    while (i < expr.length && (expr[i].isDigit() || expr[i] == '.')) { i++ }
                    tokens.add(Token(TType.NUMBER, expr.substring(start, i).toDouble()))
                    continue
                }
                when (ch) {
                    '+' -> { tokens.add(Token(TType.PLUS)); i++ }
                    '-', '−' -> { tokens.add(Token(TType.MINUS)); i++ }
                    '*', '×' -> { tokens.add(Token(TType.MUL)); i++ }
                    '/', '÷' -> { tokens.add(Token(TType.DIV)); i++ }
                    '%' -> { tokens.add(Token(TType.PERCENT)); i++ }
                    '(' -> { tokens.add(Token(TType.LPAREN)); i++ }
                    ')' -> { tokens.add(Token(TType.RPAREN)); i++ }
                    else -> throw Exception("token inválido: $ch")
                }
            }
            return tokens
        }

        private fun parseExpr(t: List<Token>, pos: Int): Pair<Double, Int> {
            var (v, p) = parseTerm(t, pos)
            while (p < t.size && (t[p].type == TType.PLUS || t[p].type == TType.MINUS)) {
                val op = t[p].type; val (rv, rp) = parseTerm(t, p + 1)
                v = if (op == TType.PLUS) v + rv else v - rv; p = rp
            }
            return Pair(v, p)
        }

        private fun parseTerm(t: List<Token>, pos: Int): Pair<Double, Int> {
            var (v, p) = parseUnary(t, pos)
            while (p < t.size && (t[p].type == TType.MUL || t[p].type == TType.DIV || t[p].type == TType.PERCENT)) {
                val op = t[p].type; val (rv, rp) = parseUnary(t, p + 1)
                v = when (op) {
                    TType.MUL -> v * rv
                    TType.DIV -> { if (rv == 0.0) throw Exception("div/0"); v / rv }
                    else -> v * (rv / 100.0)
                }; p = rp
            }
            return Pair(v, p)
        }

        private fun parseUnary(t: List<Token>, pos: Int): Pair<Double, Int> {
            if (pos < t.size && t[pos].type == TType.MINUS) {
                val (v, p) = parseUnary(t, pos + 1); return Pair(-v, p)
            }
            if (pos < t.size && t[pos].type == TType.PLUS) return parseUnary(t, pos + 1)
            return parsePrimary(t, pos)
        }

        private fun parsePrimary(t: List<Token>, pos: Int): Pair<Double, Int> {
            if (pos >= t.size) throw Exception("fin inesperado")
            if (t[pos].type == TType.NUMBER) return Pair(t[pos].value, pos + 1)
            if (t[pos].type == TType.LPAREN) {
                val (v, p) = parseExpr(t, pos + 1)
                if (p >= t.size || t[p].type != TType.RPAREN) throw Exception("paréntesis sin cerrar")
                return Pair(v, p + 1)
            }
            throw Exception("token inesperado: ${t[pos].type}")
        }

        // ── Historial ───────────────────────────────────────────────────────

        private fun loadHistory(context: Context): JSONArray {
            return try {
                val raw = context.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
                    .getString(KEY_HISTORY, null) ?: return JSONArray()
                JSONArray(raw)
            } catch (_: Exception) { JSONArray() }
        }

        private fun appendHistory(context: Context, expr: String, result: String) {
            try {
                val arr = loadHistory(context)
                val entry = JSONObject().apply {
                    put("id", System.currentTimeMillis().toString())
                    put("name", "")
                    put("expr", expr)
                    put("result", result)
                    put("updatedAt", System.currentTimeMillis())
                }
                val newArr = JSONArray()
                newArr.put(entry)
                for (i in 0 until minOf(arr.length(), 199)) newArr.put(arr.getJSONObject(i))
                context.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
                    .edit().putString(KEY_HISTORY, newArr.toString()).apply()
            } catch (_: Exception) {}
        }

        private fun historyCount(context: Context) = loadHistory(context).length()

        // ── Manejo de teclas ────────────────────────────────────────────────

        private fun handleKey(context: Context, ui: android.content.SharedPreferences, id: Int, key: String) {
            var expr = ui.getString("expr_$id", "") ?: ""
            var display = ui.getString("display_$id", "0") ?: "0"
            var evaluated = ui.getBoolean("evaluated_$id", false)
            val edit = ui.edit()

            when (key) {
                "C", "AC" -> { expr = ""; display = "0"; evaluated = false }
                "⌫" -> {
                    if (expr.isNotEmpty()) expr = expr.dropLast(1)
                    display = if (expr.isEmpty()) "0" else expr
                    evaluated = false
                }
                "=" -> {
                    if (expr.isBlank()) return
                    val result = evaluate(expr)
                    if (result != "Error") appendHistory(context, expr, result)
                    display = result
                    evaluated = true
                }
                else -> {
                    if (evaluated && (key.first().isDigit() || key == ".")) {
                        expr = key; display = key; evaluated = false
                    } else if (evaluated && isOp(key)) {
                        expr = display + key; display = expr; evaluated = false
                    } else {
                        expr += key; display = expr; evaluated = false
                    }
                }
            }
            edit.putString("expr_$id", expr)
                .putString("display_$id", display)
                .putBoolean("evaluated_$id", evaluated)
                .apply()
        }

        private fun isOp(k: String) = k in listOf("+", "−", "×", "÷", "(", ")")

        // ── Render ──────────────────────────────────────────────────────────

        fun updateAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, CalculatorWidgetProvider::class.java))
            for (id in ids) render(context, mgr, id)
        }

        private fun render(context: Context, mgr: AppWidgetManager, id: Int) {
            try { mgr.updateAppWidget(id, buildViews(context, id)) } catch (_: Exception) {}
        }

        private fun buildViews(context: Context, appWidgetId: Int): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_calculator)
            val prefs = context.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
            val cfg = readCalcCfg(prefs)
            val ui = context.getSharedPreferences(PREFS_UI, Context.MODE_PRIVATE)
            val mode = ui.getInt("mode_$appWidgetId", MODE_KEYPAD)
            val expr = ui.getString("expr_$appWidgetId", "") ?: ""
            val display = ui.getString("display_$appWidgetId", "0") ?: "0"

            // Fondo del widget
            views.setInt(R.id.calc_root, "setBackgroundColor",
                applyAlpha(cfg.bgArgb, cfg.bgAlpha))

            // Display: fondo con esquinas superiores redondeadas (cfg.borderRadius).
            // calc_display_bg es transparente; el bitmap va detrás en calc_display_rounded_bg.
            views.setImageViewBitmap(R.id.calc_display_rounded_bg,
                makeDisplayBg(cfg.displayBgArgb, cfg.borderRadius, context))
            views.setTextViewText(R.id.calc_expr, expr.ifEmpty { "" })
            views.setTextColor(R.id.calc_expr, cfg.exprColor)
            views.setTextViewTextSize(R.id.calc_expr, TypedValue.COMPLEX_UNIT_SP, cfg.exprSp)
            views.setTextViewText(R.id.calc_result, display)
            views.setTextColor(R.id.calc_result, cfg.resultColor)
            views.setTextViewTextSize(R.id.calc_result, TypedValue.COMPLEX_UNIT_SP, cfg.resultSp)

            // Expresión siempre visible (modo expandido eliminado)
            views.setViewVisibility(R.id.calc_expr,
                if (expr.isNotEmpty()) View.VISIBLE else View.GONE)

            // Botón de historial
            bindDisplayBtns(context, views, appWidgetId, cfg)

            // Visibilidad teclado vs historial
            views.setViewVisibility(R.id.calc_keypad,
                if (mode == MODE_HISTORY) View.GONE else View.VISIBLE)
            views.setViewVisibility(R.id.calc_history_panel,
                if (mode == MODE_HISTORY) View.VISIBLE else View.GONE)

            if (mode != MODE_HISTORY) {
                bindKeypad(context, views, appWidgetId, cfg)
            } else {
                bindHistory(context, views, appWidgetId, cfg)
            }

            return views
        }

        private fun bindDisplayBtns(context: Context, views: RemoteViews, id: Int, cfg: CalcCfg) {
            views.setOnClickPendingIntent(R.id.calc_btn_history,
                pi(context, ACTION_TOGGLE_HISTORY, id, 1))
            // El botón de historial es un ImageView cuadrado 32×32dp → puede usar
            // bitmap compuesto (fondo redondeado + ícono) sin distorsión.
            applyBtnIconWithRadius(views, R.id.calc_btn_history, cfg.iconHistory,
                android.R.drawable.ic_menu_recent_history, cfg.fnFg, cfg.fnBg,
                cfg.histRadius, context)
        }

        private fun bindKeypad(context: Context, views: RemoteViews, id: Int, cfg: CalcCfg) {
            val rows = listOf(
                listOf("(" to false, ")" to false, "C" to false, "÷" to true),
                listOf("7" to false, "8" to false, "9" to false, "×" to true),
                listOf("4" to false, "5" to false, "6" to false, "−" to true),
                listOf("1" to false, "2" to false, "3" to false, "+" to true),
            )
            val rowIds = listOf(R.id.calc_row0, R.id.calc_row1, R.id.calc_row2, R.id.calc_row3)
            val cellIds = listOf(
                listOf(R.id.k00, R.id.k01, R.id.k02, R.id.k03),
                listOf(R.id.k10, R.id.k11, R.id.k12, R.id.k13),
                listOf(R.id.k20, R.id.k21, R.id.k22, R.id.k23),
                listOf(R.id.k30, R.id.k31, R.id.k32, R.id.k33),
            )
            for (r in rows.indices) {
                for (c in rows[r].indices) {
                    val (label, isOp) = rows[r][c]
                    val viewId = cellIds[r][c]
                    val isFn = label in listOf("(", ")", "C")
                    val (bg, fg, sp, radius) = when {
                        isOp -> BtnStyle(cfg.opBg, cfg.opFg, cfg.opSp, cfg.opRadius)
                        isFn -> BtnStyle(cfg.fnBg, cfg.fnFg, cfg.fnSp, cfg.fnRadius)
                        else -> BtnStyle(cfg.numBg, cfg.numFg, cfg.numSp, cfg.numRadius)
                    }
                    views.setTextViewText(viewId, label)
                    views.setTextColor(viewId, fg)
                    views.setTextViewTextSize(viewId, TypedValue.COMPLEX_UNIT_SP, sp)
                    setBtnBg(views, viewId, bg, radius, context, isTextView = true)
                    views.setOnClickPendingIntent(viewId, keyPi(context, id, label, r * 4 + c + 10))
                }
                // fila vacía → no hay nada extra que hacer con rowIds
            }
            // Fila inferior: 0 . ⌫ =
            // k40 (0): ImageView — bitmap con texto "0" + esquina inferior-izquierda redondeada
            // k41 (.): TextView fn
            // k42 (⌫): ImageView icono
            // k43 (=): ImageView — bitmap con texto "=" + esquina inferior-derecha redondeada
            val fnS = BtnStyle(cfg.fnBg, cfg.fnFg, cfg.fnSp, cfg.fnRadius)
            val numS2 = BtnStyle(cfg.numBg, cfg.numFg, cfg.numSp, cfg.numRadius)
            val eqS = BtnStyle(cfg.eqBg, cfg.eqFg, cfg.eqSp, cfg.eqRadius)

            // 0 — esquina inferior-izquierda = cfg.borderRadius
            views.setImageViewBitmap(R.id.k40,
                drawCornerBtn("0", numS2.bg, numS2.fg, numS2.sp, cfg.borderRadius, BL, context))
            views.setOnClickPendingIntent(R.id.k40, keyPi(context, id, "0", 40))

            // .
            views.setTextViewText(R.id.k41, ".")
            views.setTextColor(R.id.k41, fnS.fg)
            views.setTextViewTextSize(R.id.k41, TypedValue.COMPLEX_UNIT_SP, fnS.sp)
            setBtnBg(views, R.id.k41, fnS.bg, fnS.radius, context, isTextView = true)
            views.setOnClickPendingIntent(R.id.k41, keyPi(context, id, ".", 41))

            // ⌫ (ImageView: fondo plano + ícono)
            applyBtnIcon(views, R.id.k42, cfg.iconBackspace,
                android.R.drawable.ic_input_delete, fnS.fg, fnS.bg, context)
            views.setOnClickPendingIntent(R.id.k42, keyPi(context, id, "⌫", 42))

            // = — esquina inferior-derecha = cfg.borderRadius
            views.setImageViewBitmap(R.id.k43,
                drawCornerBtn("=", eqS.bg, eqS.fg, eqS.sp, cfg.borderRadius, BR, context))
            views.setOnClickPendingIntent(R.id.k43, keyPi(context, id, "=", 43))
        }

        private fun bindHistory(context: Context, views: RemoteViews, id: Int, cfg: CalcCfg) {
            val history = loadHistory(context)
            val count = history.length()
            val ui = context.getSharedPreferences(PREFS_UI, Context.MODE_PRIVATE)
            val offset = ui.getInt("hoff_$id", 0).coerceIn(0, (count - HIST_ROWS).coerceAtLeast(0))

            val histRowIds = listOf(
                listOf(R.id.h0_expr, R.id.h0_result),
                listOf(R.id.h1_expr, R.id.h1_result),
                listOf(R.id.h2_expr, R.id.h2_result),
            )
            val histRootIds = listOf(R.id.h0, R.id.h1, R.id.h2)

            for (i in 0 until HIST_ROWS) {
                val idx = offset + i
                val rowRoot = histRootIds[i]
                if (idx >= count) {
                    views.setViewVisibility(rowRoot, View.INVISIBLE)
                } else {
                    views.setViewVisibility(rowRoot, View.VISIBLE)
                    val entry = history.optJSONObject(idx)
                    val name = entry?.optString("name", "")?.takeIf { it.isNotBlank() }
                    val expr = entry?.optString("expr", "") ?: ""
                    val result = entry?.optString("result", "") ?: ""
                    views.setTextViewText(histRowIds[i][0], name ?: expr)
                    views.setTextColor(histRowIds[i][0], cfg.exprColor)
                    views.setTextViewText(histRowIds[i][1], "= $result")
                    views.setTextColor(histRowIds[i][1], cfg.resultColor)
                    // Al tocar, carga el resultado
                    val loadIntent = Intent(context, CalculatorWidgetProvider::class.java)
                        .setAction(ACTION_LOAD_HIST)
                        .putExtra(EXTRA_WIDGET_ID, id)
                        .putExtra(EXTRA_HIST_RESULT, result)
                    val loadPi = PendingIntent.getBroadcast(
                        context, id * 1000 + 200 + i, loadIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
                    )
                    views.setOnClickPendingIntent(rowRoot, loadPi)
                }
            }
            // ▲▼
            views.setOnClickPendingIntent(R.id.calc_hist_up, pi(context, ACTION_HIST_UP, id, 90))
            views.setOnClickPendingIntent(R.id.calc_hist_down, pi(context, ACTION_HIST_DOWN, id, 91))
            views.setTextColor(R.id.calc_hist_up,   if (offset > 0) 0xFFFFFFFF.toInt() else 0x40FFFFFF)
            views.setTextColor(R.id.calc_hist_down, if (offset < count - HIST_ROWS) 0xFFFFFFFF.toInt() else 0x40FFFFFF)
        }

        // ── Helpers de dibujo ───────────────────────────────────────────────

        private data class BtnStyle(val bg: Int, val fg: Int, val sp: Float, val radius: Int)

        // IMPORTANTE: `setImageViewBitmap` solo es válido sobre un ImageView real.
        // Llamarlo sobre un TextView no falla al construir la acción (se evalúa
        // perezosamente) pero SÍ falla cuando el launcher la aplica, lo que deja
        // el widget marcado como "roto"/"a reparar". Por eso los TextView
        // (dígitos, operadores, paréntesis, C) siempre usan color plano.
        private fun setBtnBg(
            views: RemoteViews, viewId: Int, bgColor: Int, radiusDp: Int,
            context: Context, isTextView: Boolean = false
        ) {
            if (isTextView || radiusDp <= 0) {
                try { views.setInt(viewId, "setBackgroundColor", bgColor) } catch (_: Exception) {}
                return
            }
            val px = dp(context, radiusDp.toFloat())
            val bmp = drawRoundRect(bgColor, px, context)
            if (bmp != null) {
                try { views.setImageViewBitmap(viewId, bmp) } catch (_: Exception) {
                    try { views.setInt(viewId, "setBackgroundColor", bgColor) } catch (_: Exception) {}
                }
            } else {
                try { views.setInt(viewId, "setBackgroundColor", bgColor) } catch (_: Exception) {}
            }
        }

        private fun drawRoundRect(color: Int, radiusPx: Int, context: Context): Bitmap? {
            return try {
                val size = 120
                val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
                val c = Canvas(bmp)
                val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color }
                val r = radiusPx.toFloat().coerceAtLeast(0f)
                c.drawRoundRect(RectF(0f, 0f, size.toFloat(), size.toFloat()), r, r, paint)
                bmp
            } catch (_: Exception) { null }
        }

        // Pinta el fondo de la ImageView con setBackgroundColor (llena el área entera
        // sin depender del tamaño del bitmap) y el ícono con setImageViewBitmap.
        // Así el resultado es idéntico al _iconBtn de la preview Flutter: fondo de
        // color sólido + ícono centrado con scaleType del layout.
        private fun applyBtnIcon(
            views: RemoteViews, viewId: Int, b64: String,
            fallbackResId: Int, tint: Int, bg: Int, context: Context
        ) {
            try { views.setInt(viewId, "setBackgroundColor", bg) } catch (_: Exception) {}

            val iconBmp: Bitmap? = if (b64.isNotBlank()) {
                decodeBitmap(b64, 96)
            } else if (fallbackResId > 0) {
                try {
                    val d = context.getDrawable(fallbackResId)?.mutate()
                    if (d != null) {
                        d.setTint(tint)
                        val sz = 96
                        val bmp = Bitmap.createBitmap(sz, sz, Bitmap.Config.ARGB_8888)
                        d.setBounds(0, 0, sz, sz)
                        d.draw(Canvas(bmp))
                        bmp
                    } else null
                } catch (_: Exception) { null }
            } else null

            if (iconBmp != null) {
                try { views.setImageViewBitmap(viewId, iconBmp) } catch (_: Exception) {}
            }
        }

        // Máscaras de esquina para drawCornerBtn (solo la esquina indicada lleva radio)
        private const val TL = 0  // top-left
        private const val TR = 1  // top-right
        private const val BR = 2  // bottom-right
        private const val BL = 3  // bottom-left

        // Crea el fondo del display con esquinas superiores redondeadas.
        // Bitmap 4:1 para minimizar distorsión de esquinas al hacer fitXY sobre el display.
        private fun makeDisplayBg(bgColor: Int, radiusDp: Int, context: Context): Bitmap {
            val w = 800; val h = 200
            val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            val px = if (radiusDp > 0) dp(context, radiusDp.toFloat()).toFloat() else 0f
            val radii = floatArrayOf(px, px, px, px, 0f, 0f, 0f, 0f)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = bgColor }
            val path = Path()
            path.addRoundRect(RectF(0f, 0f, w.toFloat(), h.toFloat()), radii, Path.Direction.CW)
            canvas.drawPath(path, paint)
            return bmp
        }

        // Dibuja un botón texto con UNA esquina redondeada (para k40 y k43).
        // Bitmap cuadrado 240×240 — se usa fitXY sobre celdas aproximadamente cuadradas.
        private fun drawCornerBtn(
            text: String, bgColor: Int, fgColor: Int, textSpScaled: Float,
            radiusDp: Int, corner: Int, context: Context
        ): Bitmap {
            val sz = 240
            val bmp = Bitmap.createBitmap(sz, sz, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            val f = sz.toFloat()
            val px = if (radiusDp > 0) dp(context, radiusDp.toFloat()).toFloat() else 0f
            val radii = when (corner) {
                TL -> floatArrayOf(px, px, 0f, 0f, 0f, 0f, 0f, 0f)
                TR -> floatArrayOf(0f, 0f, px, px, 0f, 0f, 0f, 0f)
                BR -> floatArrayOf(0f, 0f, 0f, 0f, px, px, 0f, 0f)
                BL -> floatArrayOf(0f, 0f, 0f, 0f, 0f, 0f, px, px)
                else -> FloatArray(8) { 0f }
            }
            val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = bgColor }
            val path = Path()
            path.addRoundRect(RectF(0f, 0f, f, f), radii, Path.Direction.CW)
            canvas.drawPath(path, bgPaint)
            // Texto centrado: tamaño en sp escalado (ya viene multiplicado por scale en CalcCfg)
            val textPx = (textSpScaled * context.resources.displayMetrics.scaledDensity)
                .coerceIn(24f, sz * 0.55f)
            val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = fgColor
                textSize = textPx
                typeface = Typeface.DEFAULT
                textAlign = Paint.Align.CENTER
            }
            val textY = f / 2f - (textPaint.descent() + textPaint.ascent()) / 2f
            canvas.drawText(text, f / 2f, textY, textPaint)
            return bmp
        }

        // Para ImageViews cuadrados: compone fondo redondeado + ícono en un único bitmap
        // (fitXY en layout cuadrado no distorsiona las esquinas).
        private fun applyBtnIconWithRadius(
            views: RemoteViews, viewId: Int, b64: String,
            fallbackResId: Int, tint: Int, bg: Int, radiusDp: Int, context: Context
        ) {
            if (radiusDp <= 0) {
                applyBtnIcon(views, viewId, b64, fallbackResId, tint, bg, context)
                return
            }
            val size = 120
            val px = dp(context, radiusDp.toFloat()).toFloat()
            val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            // 1. Fondo redondeado
            val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = bg }
            canvas.drawRoundRect(RectF(0f, 0f, size.toFloat(), size.toFloat()), px, px, bgPaint)
            // 2. Ícono centrado (60% del tamaño)
            val iconSz = (size * 0.6f).toInt()
            val off = (size - iconSz) / 2
            val iconBmp: Bitmap? = if (b64.isNotBlank()) {
                decodeBitmap(b64, iconSz)
            } else if (fallbackResId > 0) {
                try {
                    val d = context.getDrawable(fallbackResId)?.mutate()
                    if (d != null) {
                        d.setTint(tint)
                        val ib = Bitmap.createBitmap(iconSz, iconSz, Bitmap.Config.ARGB_8888)
                        d.setBounds(0, 0, iconSz, iconSz)
                        d.draw(Canvas(ib))
                        ib
                    } else null
                } catch (_: Exception) { null }
            } else null
            if (iconBmp != null) canvas.drawBitmap(iconBmp, off.toFloat(), off.toFloat(), null)
            try { views.setImageViewBitmap(viewId, bmp) } catch (_: Exception) {
                try { views.setInt(viewId, "setBackgroundColor", bg) } catch (_: Exception) {}
            }
        }

        private fun decodeBitmap(b64: String, maxSide: Int): Bitmap? {
            if (b64.isBlank()) return null
            val bytes = try { Base64.decode(b64, Base64.DEFAULT) } catch (_: Exception) { null } ?: return null
            val bmp = try { BitmapFactory.decodeByteArray(bytes, 0, bytes.size) } catch (_: Exception) { null } ?: return null
            val w = bmp.width; val h = bmp.height
            if (w <= maxSide && h <= maxSide) return bmp
            val ratio = maxSide.toFloat() / maxOf(w, h).toFloat()
            return try { Bitmap.createScaledBitmap(bmp, (w * ratio).toInt().coerceAtLeast(1),
                (h * ratio).toInt().coerceAtLeast(1), true) } catch (_: Exception) { bmp }
        }

        private fun applyAlpha(argb: Int, alpha: Int): Int {
            val a = alpha.coerceIn(0, 255)
            return (a shl 24) or (argb and 0x00FFFFFF)
        }

        private fun dp(context: Context, v: Float): Int =
            (v * context.resources.displayMetrics.density).toInt().coerceAtLeast(1)

        // ── Helpers de SharedPreferences ─────────────────────────────────────

        private fun fLong(p: android.content.SharedPreferences, k: String, d: Long): Long =
            try { when (val v = p.all[k]) {
                is Long -> v; is Int -> v.toLong(); is Float -> v.toLong()
                is Double -> v.toLong(); is String -> v.toLongOrNull() ?: d; else -> d
            } } catch (_: Exception) { d }

        private fun fInt(p: android.content.SharedPreferences, k: String, d: Int): Int =
            fLong(p, k, d.toLong()).toInt()

        private fun fColor(p: android.content.SharedPreferences, k: String, d: Int): Int =
            fLong(p, k, d.toLong() and 0xFFFFFFFFL).toInt()

        private fun fStr(p: android.content.SharedPreferences, k: String): String =
            try { (p.all[k] as? String)?.takeIf { it.isNotEmpty() } ?: "" } catch (_: Exception) { "" }

        // ── PendingIntents ───────────────────────────────────────────────────

        private fun pi(context: Context, action: String, id: Int, code: Int): PendingIntent {
            val i = Intent(context, CalculatorWidgetProvider::class.java)
                .setAction(action).putExtra(EXTRA_WIDGET_ID, id)
            return PendingIntent.getBroadcast(
                context, id * 100 + code, i,
                PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
            )
        }

        private fun keyPi(context: Context, id: Int, key: String, code: Int): PendingIntent {
            val i = Intent(context, CalculatorWidgetProvider::class.java)
                .setAction(ACTION_KEY)
                .putExtra(EXTRA_WIDGET_ID, id)
                .putExtra(EXTRA_KEY, key)
            return PendingIntent.getBroadcast(
                context, id * 100 + code, i,
                PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
            )
        }

        private fun immutableFlag(): Int =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0

        // Suprimir advertencia de import no usado (Typeface se usa implícitamente en setTextViewTextSize)
        @Suppress("UNUSED_VARIABLE")
        private val _tf = Typeface.DEFAULT
    }
}
