const API_BASE = import.meta.env.VITE_API_BASE_URL || '/api'

async function request(path, options = {}) {
  const res = await fetch(`${API_BASE}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  })
  if (!res.ok) {
    const body = await res.json().catch(() => ({}))
    throw new Error(body.detail || `Request failed: ${res.status}`)
  }
  if (res.status === 204) return null
  return res.json()
}

export const getTodos = () => request('/todos')

export const createTodo = (title) =>
  request('/todos', { method: 'POST', body: JSON.stringify({ title }) })

export const updateTodo = (id, changes) =>
  request(`/todos/${id}`, { method: 'PATCH', body: JSON.stringify(changes) })

export const deleteTodo = (id) => request(`/todos/${id}`, { method: 'DELETE' })
