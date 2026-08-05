import { describe, expect, it } from 'vitest'
import { isPinRequiredError, isValidAdultPin } from './adultPin'

describe('adult PIN validation', () => {
  it.each(['1234', '12345', '123456'])('accepts %s', pin => {
    expect(isValidAdultPin(pin)).toBe(true)
  })

  it.each(['123', '1234567', '12a4', ''])('rejects %s', pin => {
    expect(isValidAdultPin(pin)).toBe(false)
  })

  it('only identifies the expected missing-PIN server error', () => {
    expect(isPinRequiredError('PIN required')).toBe(true)
    expect(isPinRequiredError('admin required')).toBe(false)
  })
})
