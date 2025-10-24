// Jest setup file for testing React components
import '@testing-library/jest-dom';

// Mock window.location to simulate Twitch hosted environment
// This ensures components use the production API URL (https://premiere-ecoute.fr)
Object.defineProperty(window, 'location', {
  value: {
    hostname: 'test.ext-twitch.tv',
    href: 'https://test.ext-twitch.tv',
    search: '',
  },
  writable: true,
  configurable: true
});

// Mock global fetch for API calls
global.fetch = jest.fn();

// Mock console methods to reduce noise in tests
global.console = {
  ...console,
  log: jest.fn(),
  error: jest.fn(),
  warn: jest.fn(),
};

// Mock timers
beforeEach(() => {
  jest.clearAllMocks();
  jest.clearAllTimers();
  // Reset fetch mock implementation
  fetch.mockReset();
});

afterEach(() => {
  jest.runOnlyPendingTimers();
  jest.useRealTimers();
});