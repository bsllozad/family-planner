export const isValidAdultPin = (pin: string) => /^\d{4,6}$/.test(pin)

export const isPinRequiredError = (message?: string) =>
  message?.toLowerCase().includes('pin required') ?? false

