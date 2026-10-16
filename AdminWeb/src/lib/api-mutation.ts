import axios from 'axios'
import type { AxiosResponse } from 'axios'
import type { z } from 'zod'
import { UnconfirmedMutationError } from './api-error.ts'

async function mutationResponse(request: () => Promise<AxiosResponse>) {
  try { return await request() }
  catch (error) {
    // A lost response or a gateway/server error does not prove that no write happened.
    if (axios.isAxiosError(error) && (!error.response || error.response.status >= 500)) throw new UnconfirmedMutationError()
    throw error
  }
}

export async function confirmedMutation<T>(request: () => Promise<AxiosResponse>, schema: z.ZodType<T>, status: number, matches: (data: T) => boolean): Promise<T> {
  const response = await mutationResponse(request)
  const result = schema.safeParse(response.data)
  if (response.status !== status || !result.success || !matches(result.data)) throw new UnconfirmedMutationError()
  return result.data
}

export async function confirmedNoContent(request: () => Promise<AxiosResponse>): Promise<void> {
  const response = await mutationResponse(request)
  // Hide/restore/delete return 204. Do not parse or require a JSON body.
  if (response.status !== 204) throw new UnconfirmedMutationError()
}
