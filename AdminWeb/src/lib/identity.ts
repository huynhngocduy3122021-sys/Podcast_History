export type SessionIdentity = { id: string; role: string }

export function identityOf(value: { id: string; role: string } | null | undefined): SessionIdentity | null {
  return value ? { id: value.id, role: value.role } : null
}

export function sameIdentity(expected: SessionIdentity | null, current: SessionIdentity | null): boolean {
  return Boolean(expected && current && expected.id === current.id && expected.role === current.role)
}
