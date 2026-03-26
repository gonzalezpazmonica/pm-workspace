"""Tests del sistema de supervivencia ZeroClaw.

Cobertura:
  - phase_latido: escritura a disco, espacio
  - phase_respiracion: servidor inalcanzable, bridge caído, bridge ok
  - phase_despertar: claude responde, no responde
  - survival_tick: intervalos, orquestación
  - consciousness.py: integración (AST)
  - nctalk: escalación (mock)

Ejecutar: python3 -m pytest tests/zeroclaw/test_survival.py -v
"""
import ast
import os
import time
import shutil
import tempfile
import unittest
from unittest.mock import patch, MagicMock


class TestPhaseLatido(unittest.TestCase):

    def test_escribe_heartbeat_a_disco(self):
        from zeroclaw.host.survival import phase_latido
        result = phase_latido(ser=None)
        self.assertTrue(result["ok"], f"latido falló: {result['details']}")
        self.assertIn("disk:ok", result["details"])
        hb = os.path.expanduser("~/.savia/zeroclaw/heartbeat.ts")
        self.assertTrue(os.path.isfile(hb), "heartbeat.ts no creado")

    def test_disk_space_reportado(self):
        from zeroclaw.host.survival import phase_latido
        result = phase_latido(ser=None)
        has_disk_space = any("disk_space" in d for d in result["details"])
        self.assertTrue(has_disk_space, "disk_space no reportado")

    def test_disco_lleno_simulado(self):
        from zeroclaw.host.survival import phase_latido
        with patch("shutil.disk_usage") as mock_du:
            mock_du.return_value = MagicMock(free=100 * 1024 * 1024)  # 100 MB
            result = phase_latido(ser=None)
        low = any("disk_space:low" in d for d in result["details"])
        self.assertTrue(low, "no detectó disco con poco espacio")

    def test_fallo_escritura_disco(self):
        from zeroclaw.host.survival import phase_latido
        with patch("os.makedirs", side_effect=PermissionError("sin permisos")):
            result = phase_latido(ser=None)
        self.assertFalse(result["ok"])
        self.assertTrue(any("disk:fail" in d for d in result["details"]))


class TestPhaseRespiracion(unittest.TestCase):

    def _state(self):
        return {
            "consecutive_breath_failures": 0,
            "remote_unreachable_since": None,
            "last_breath": 0,
        }

    def test_servidor_inalcanzable_incrementa_contador(self):
        from zeroclaw.host import survival_phases as sp
        state = self._state()
        with patch("zeroclaw.host.remote_host.is_reachable", return_value=False):
            result = sp.phase_respiracion(state)
        self.assertFalse(result["ok"])
        self.assertEqual(result["bridge"], "unreachable")
        self.assertEqual(state["consecutive_breath_failures"], 1)
        self.assertIsNotNone(state["remote_unreachable_since"])

    def test_servidor_inalcanzable_acumula(self):
        from zeroclaw.host import survival_phases as sp
        state = self._state()
        state["consecutive_breath_failures"] = 1
        with patch("zeroclaw.host.remote_host.is_reachable", return_value=False):
            sp.phase_respiracion(state)
        self.assertEqual(state["consecutive_breath_failures"], 2)

    def test_bridge_caido_se_reinicia(self):
        from zeroclaw.host import survival_phases as sp
        state = self._state()
        with patch("zeroclaw.host.remote_host.is_reachable", return_value=True), \
             patch("zeroclaw.host.remote_host.is_bridge_running", return_value=False), \
             patch("zeroclaw.host.remote_host.restart_bridge",
                   return_value=(True, "bridge started")):
            result = sp.phase_respiracion(state)
        self.assertTrue(result["healed"])
        self.assertEqual(result["bridge"], "restarted")
        self.assertEqual(state["consecutive_breath_failures"], 0)
        self.assertIsNone(state["remote_unreachable_since"])

    def test_bridge_caido_reinicio_falla(self):
        from zeroclaw.host import survival_phases as sp
        state = self._state()
        with patch("zeroclaw.host.remote_host.is_reachable", return_value=True), \
             patch("zeroclaw.host.remote_host.is_bridge_running", return_value=False), \
             patch("zeroclaw.host.remote_host.restart_bridge",
                   return_value=(False, "timeout")):
            result = sp.phase_respiracion(state)
        self.assertFalse(result["ok"])
        self.assertFalse(result["healed"])
        self.assertEqual(state["consecutive_breath_failures"], 1)

    def test_todo_ok_resetea_contador(self):
        from zeroclaw.host import survival_phases as sp
        state = self._state()
        state["consecutive_breath_failures"] = 2
        with patch("zeroclaw.host.remote_host.is_reachable", return_value=True), \
             patch("zeroclaw.host.remote_host.is_bridge_running", return_value=True):
            result = sp.phase_respiracion(state)
        self.assertTrue(result["ok"])
        self.assertEqual(result["bridge"], "ok")
        self.assertEqual(state["consecutive_breath_failures"], 0)

    def test_escala_a_monica_al_tercer_fallo(self):
        from zeroclaw.host import survival_phases as sp
        state = self._state()
        state["consecutive_breath_failures"] = 2  # va a llegar a 3
        with patch("zeroclaw.host.remote_host.is_reachable", return_value=False), \
             patch("zeroclaw.host.survival_phases._notify_monica") as mock_notify:
            sp.phase_respiracion(state)
        mock_notify.assert_called_once_with("respiracion", unittest.mock.ANY)

    def test_no_escala_antes_del_limite(self):
        from zeroclaw.host import survival_phases as sp
        state = self._state()
        state["consecutive_breath_failures"] = 0
        with patch("zeroclaw.host.remote_host.is_reachable", return_value=False), \
             patch("zeroclaw.host.survival_phases._notify_monica") as mock_notify:
            sp.phase_respiracion(state)
        mock_notify.assert_not_called()


class TestPhaseDespertar(unittest.TestCase):

    def _state(self):
        return {"consecutive_wakeup_failures": 0, "last_wakeup": 0}

    def test_claude_responde(self):
        from zeroclaw.host import survival_phases as sp
        state = self._state()
        with patch("zeroclaw.host.remote_host.is_reachable", return_value=True), \
             patch("zeroclaw.host.remote_host.wake_claude",
                   return_value=(True, "Estoy activa")):
            result = sp.phase_despertar(state)
        self.assertTrue(result["ok"])
        self.assertEqual(result["claude_responds"], "ok")
        self.assertEqual(state["consecutive_wakeup_failures"], 0)

    def test_claude_no_responde_incrementa(self):
        from zeroclaw.host import survival_phases as sp
        state = self._state()
        with patch("zeroclaw.host.remote_host.is_reachable", return_value=True), \
             patch("zeroclaw.host.remote_host.wake_claude",
                   return_value=(False, "")):
            result = sp.phase_despertar(state)
        self.assertFalse(result["ok"])
        self.assertEqual(result["claude_responds"], "no_response")
        self.assertEqual(state["consecutive_wakeup_failures"], 1)

    def test_remoto_inalcanzable(self):
        from zeroclaw.host import survival_phases as sp
        state = self._state()
        with patch("zeroclaw.host.remote_host.is_reachable", return_value=False):
            result = sp.phase_despertar(state)
        self.assertFalse(result["ok"])
        self.assertEqual(result["claude_responds"], "remote_unreachable")
        self.assertEqual(state["consecutive_wakeup_failures"], 1)

    def test_escala_al_segundo_fallo(self):
        from zeroclaw.host import survival_phases as sp
        state = self._state()
        state["consecutive_wakeup_failures"] = 1
        with patch("zeroclaw.host.remote_host.is_reachable", return_value=True), \
             patch("zeroclaw.host.remote_host.wake_claude", return_value=(False, "")), \
             patch("zeroclaw.host.survival_phases._notify_monica") as mock_notify:
            sp.phase_despertar(state)
        mock_notify.assert_called_once_with("despertar", unittest.mock.ANY)


class TestSurvivalTick(unittest.TestCase):

    def setUp(self):
        from zeroclaw.host import survival
        self._survival = survival
        survival._state.update({
            "last_heartbeat": 0.0,
            "last_breath": 0.0,
            "last_wakeup": 0.0,
            "consecutive_breath_failures": 0,
            "consecutive_wakeup_failures": 0,
            "remote_unreachable_since": None,
        })

    def test_ejecuta_todas_las_fases_si_toca(self):
        with patch.object(self._survival, "phase_latido",
                          return_value={"ok": True}) as m_lat, \
             patch.object(self._survival, "phase_respiracion",
                          return_value={"ok": True, "details": []}) as m_resp, \
             patch.object(self._survival, "phase_despertar",
                          return_value={"ok": True, "details": []}) as m_desp:
            result = self._survival.survival_tick(ser=None, run_claude_fn=None)
        self.assertIn("latido", result)
        self.assertIn("respiracion", result)
        self.assertIn("despertar", result)
        self.assertTrue(m_lat.called)
        self.assertTrue(m_resp.called)
        self.assertTrue(m_desp.called)

    def test_no_ejecuta_si_no_toca(self):
        now = time.time()
        self._survival._state["last_heartbeat"] = now
        self._survival._state["last_breath"] = now
        self._survival._state["last_wakeup"] = now
        with patch.object(self._survival, "phase_latido") as m_lat, \
             patch.object(self._survival, "phase_respiracion") as m_resp, \
             patch.object(self._survival, "phase_despertar") as m_desp:
            result = self._survival.survival_tick(ser=None, run_claude_fn=None)
        self.assertNotIn("latido", result)
        self.assertFalse(m_lat.called)
        self.assertFalse(m_resp.called)
        self.assertFalse(m_desp.called)

    def test_solo_latido_si_solo_toca_latido(self):
        now = time.time()
        self._survival._state["last_heartbeat"] = 0.0   # vencido
        self._survival._state["last_breath"] = now       # fresco
        self._survival._state["last_wakeup"] = now       # fresco
        with patch.object(self._survival, "phase_latido",
                          return_value={"ok": True}) as m_lat, \
             patch.object(self._survival, "phase_respiracion") as m_resp, \
             patch.object(self._survival, "phase_despertar") as m_desp:
            result = self._survival.survival_tick(ser=None, run_claude_fn=None)
        self.assertIn("latido", result)
        self.assertFalse(m_resp.called)
        self.assertFalse(m_desp.called)


class TestNotifyMonica(unittest.TestCase):

    def test_notifica_via_talk(self):
        from zeroclaw.host import survival_phases as sp
        with patch("zeroclaw.host.nctalk.notify_with_escalation",
                   return_value=True) as mock_notify:
            sp._notify_monica("respiracion", {"details": ["remote:unreachable"]})
        mock_notify.assert_called_once()
        args = mock_notify.call_args[0]
        self.assertIn("no puedo comunicarme", args[0])

    def test_notifica_fase_despertar(self):
        from zeroclaw.host import survival_phases as sp
        with patch("zeroclaw.host.nctalk.notify_with_escalation",
                   return_value=True) as mock_notify:
            sp._notify_monica("despertar", {"details": ["claude:no_response"]})
        mock_notify.assert_called_once()
        args = mock_notify.call_args[0]
        self.assertIn("Claude Code", args[0])


class TestConsciousnessIntegracion(unittest.TestCase):
    """Verifica via AST que consciousness.py integra survival_tick correctamente."""

    def test_import_survival_tick(self):
        with open("/home/monica/claude/zeroclaw/host/consciousness.py") as f:
            src = f.read()
        self.assertIn("from .survival import survival_tick as _survival_tick", src)

    def test_llamada_en_tick(self):
        with open("/home/monica/claude/zeroclaw/host/consciousness.py") as f:
            src = f.read()
        tree = ast.parse(src)
        tick_src = None
        for node in ast.walk(tree):
            if isinstance(node, ast.FunctionDef) and node.name == "tick":
                tick_src = ast.get_source_segment(src, node)
                break
        self.assertIsNotNone(tick_src, "función tick() no encontrada")
        self.assertIn("_survival_tick(ser", tick_src)

    def test_survival_tick_antes_de_return(self):
        with open("/home/monica/claude/zeroclaw/host/consciousness.py") as f:
            lines = f.readlines()
        survival_line = None
        return_line = None
        for i, line in enumerate(lines):
            if "_survival_tick(ser" in line:
                survival_line = i
            if "return last_runs" in line:
                return_line = i
        self.assertIsNotNone(survival_line, "_survival_tick no encontrado")
        self.assertIsNotNone(return_line, "return last_runs no encontrado")
        self.assertLess(survival_line, return_line,
                        "_survival_tick debe ir ANTES de return last_runs")

    def test_limite_150_lineas_todos_los_modulos(self):
        modulos = [
            "zeroclaw/host/consciousness.py",
            "zeroclaw/host/survival.py",
            "zeroclaw/host/survival_phases.py",
            "zeroclaw/host/remote_host.py",
        ]
        for modulo in modulos:
            path = f"/home/monica/claude/{modulo}"
            with open(path) as f:
                lineas = f.readlines()
            self.assertLessEqual(
                len(lineas), 150,
                f"{modulo} tiene {len(lineas)} líneas (límite: 150)"
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
