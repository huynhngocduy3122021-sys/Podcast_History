import { z } from 'zod'

// Spring Data Page: page indices start at zero. Categories are not paginated.
export function pageSchema<T extends z.ZodType>(item: T) {
  return z.object({
    content: z.array(item),
    number: z.number().int().nonnegative(),
    size: z.number().int().positive(),
    totalElements: z.number().int().nonnegative(),
    totalPages: z.number().int().nonnegative(),
  })
}

export type PageInfo = { number: number; size: number; totalElements: number; totalPages: number }
