// Jest setup file for testing React components
import '@testing-library/jest-dom';

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