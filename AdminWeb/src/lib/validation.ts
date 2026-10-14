import { z } from 'zod'

// Match Jakarta @Size: Java String.length counts UTF-16 code units.
export const textWithLimit = (max: number, message: string) => z.string().refine(value => value.length <= max, message)
