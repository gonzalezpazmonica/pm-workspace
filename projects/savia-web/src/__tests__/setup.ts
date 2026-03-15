import { config } from '@vue/test-utils'
import i18n from '../locales'

// Use English locale in tests so text assertions match
i18n.global.locale.value = 'en'

// Register i18n plugin globally for all component tests
config.global.plugins = [i18n]
