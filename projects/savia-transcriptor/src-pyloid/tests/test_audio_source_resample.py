"""Resampler tests for SoundDeviceAudioSource.

The actual sounddevice stream needs real hardware, but the resample function
is pure and unit-testable. These tests verify that 48k→16k and 44.1k→16k
streams join cleanly across blocks (no clicks, no duplicated samples) and
that the output rate ratio is accurate to within rounding.
"""

import numpy as np
import pytest

from services.recording.audio_source import SoundDeviceAudioSource


def _resampler(src: int, dst: int) -> SoundDeviceAudioSource:
    """Construct a SoundDeviceAudioSource just to access its _resample helper;
    we never call start() so no real stream is opened."""
    s = SoundDeviceAudioSource(device_id=0, sample_rate=dst)
    s._resample_phase = 0.0  # belt-and-braces
    return s


class TestResampleRatio:
    @pytest.mark.parametrize("src,dst", [(48000, 16000), (44100, 16000), (16000, 16000)])
    def test_output_size_matches_ratio(self, src, dst):
        s = _resampler(src, dst)
        blocks_in = src // 1024
        input_samples = blocks_in * 1024
        emitted = 0
        for _ in range(blocks_in):
            block = np.ones(1024, dtype=np.float32) * 0.5
            out = s._resample(block, src, dst)
            emitted += out.size
        expected = input_samples * dst / src
        # Tight tolerance — linear resampling should be within a couple samples.
        assert abs(emitted - expected) <= 2, (
            f"src={src} dst={dst}: emitted {emitted}, expected ≈ {expected:.1f}"
        )

    def test_no_resample_when_rates_match(self):
        s = _resampler(16000, 16000)
        block = np.linspace(-1, 1, 1024, dtype=np.float32)
        out = s._resample(block, 16000, 16000)
        # Math still runs but should match input length within ±1.
        assert abs(out.size - 1024) <= 1


class TestResampleContinuity:
    def test_phase_carries_across_blocks(self):
        """Feeding a constant tone in three blocks should produce one
        continuous flat output — no audible click at block boundaries."""
        s = _resampler(48000, 16000)
        outputs = []
        for _ in range(3):
            block = np.full(1024, 0.7, dtype=np.float32)
            outputs.append(s._resample(block, 48000, 16000))
        joined = np.concatenate(outputs)
        # All samples should be the constant value (no glitches).
        assert np.allclose(joined, 0.7, atol=1e-3)

    def test_linear_ramp_stays_monotonic(self):
        """A monotonically increasing input should produce a monotonically
        increasing output (no discontinuities at block boundaries)."""
        s = _resampler(48000, 16000)
        ramp = np.linspace(0, 1, 48000, dtype=np.float32)
        outputs = []
        for start in range(0, 48000, 1024):
            block = ramp[start:start + 1024]
            if block.size == 0:
                break
            outputs.append(s._resample(block, 48000, 16000))
        joined = np.concatenate(outputs)
        # Monotonic non-decreasing (allowing tiny float noise).
        diffs = np.diff(joined)
        assert (diffs >= -1e-6).all(), "Resampled ramp must not go backwards"


class TestEmptyAndEdge:
    def test_empty_block_returns_empty(self):
        s = _resampler(48000, 16000)
        out = s._resample(np.zeros(0, dtype=np.float32), 48000, 16000)
        assert out.size == 0

    def test_tiny_block_still_produces_output(self):
        s = _resampler(48000, 16000)
        # 4 samples at 48k → ~1 sample at 16k
        out = s._resample(np.ones(4, dtype=np.float32) * 0.3, 48000, 16000)
        assert out.size >= 1
        assert np.allclose(out, 0.3, atol=1e-3)
