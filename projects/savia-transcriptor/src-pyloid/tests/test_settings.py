import pytest
from pathlib import Path
import tempfile
from services.database import DatabaseService
from services.settings import SettingsService, Settings, WHISPER_MODELS, WHISPER_LANGUAGES


@pytest.fixture
def db():
    """Create a temporary database for testing."""
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = Path(tmpdir) / "test.db"
        yield DatabaseService(db_path)


@pytest.fixture
def settings_service(db):
    """Create a SettingsService with test database."""
    return SettingsService(db)


class TestSettingsService:
    def test_get_default_settings(self, settings_service):
        """New installation returns default settings."""
        settings = settings_service.get_settings()

        assert settings.language == "auto"
        assert settings.model == "tiny"
        assert settings.auto_start == True
        assert settings.retention == -1  # Forever
        assert settings.theme == "dark"
        assert settings.onboarding_complete == False

    def test_update_language(self, settings_service):
        """Can update language setting."""
        settings_service.update_settings(language="en")
        settings = settings_service.get_settings()

        assert settings.language == "en"

    def test_update_model(self, settings_service):
        """Can update whisper model setting."""
        settings_service.update_settings(model="base")
        settings = settings_service.get_settings()

        assert settings.model == "base"

    def test_update_auto_start(self, settings_service):
        """Can toggle auto-start setting."""
        settings_service.update_settings(auto_start=False)
        settings = settings_service.get_settings()

        assert settings.auto_start == False

    def test_update_retention(self, settings_service):
        """Can update history retention days."""
        settings_service.update_settings(retention=30)
        settings = settings_service.get_settings()

        assert settings.retention == 30

    def test_update_theme(self, settings_service):
        """Can update theme setting."""
        settings_service.update_settings(theme="dark")
        settings = settings_service.get_settings()

        assert settings.theme == "dark"

    def test_mark_onboarding_complete(self, settings_service):
        """Can mark onboarding as complete."""
        settings_service.update_settings(onboarding_complete=True)
        settings = settings_service.get_settings()

        assert settings.onboarding_complete == True

    def test_update_multiple_settings(self, settings_service):
        """Can update multiple settings at once."""
        settings_service.update_settings(
            language="es",
            model="small",
            theme="light"
        )
        settings = settings_service.get_settings()

        assert settings.language == "es"
        assert settings.model == "small"
        assert settings.theme == "light"

    def test_settings_persist_across_instances(self, db):
        """Settings persist when creating new service instance."""
        service1 = SettingsService(db)
        service1.update_settings(language="fr", model="medium")

        # Create new instance with same database
        service2 = SettingsService(db)
        settings = service2.get_settings()

        assert settings.language == "fr"
        assert settings.model == "medium"

    def test_get_available_models(self, settings_service):
        """Returns list of available whisper models."""
        models = settings_service.get_available_models()

        assert "tiny" in models
        assert "base" in models
        assert "small" in models
        assert "medium" in models
        assert "large-v3" in models
        assert "turbo" in models

    def test_get_available_languages(self, settings_service):
        """Returns list of available languages including auto."""
        languages = settings_service.get_available_languages()

        assert "auto" in languages
        assert "en" in languages
        assert "es" in languages
        assert "fr" in languages

    def test_get_retention_options(self, settings_service):
        """Returns retention options as dict."""
        options = settings_service.get_retention_options()

        assert "7 days" in options
        assert options["7 days"] == 7
        assert "Forever" in options
        assert options["Forever"] == -1

    def test_get_theme_options(self, settings_service):
        """Returns available theme options."""
        themes = settings_service.get_theme_options()

        assert "system" in themes
        assert "light" in themes
        assert "dark" in themes
