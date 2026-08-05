import { useEffect, useState } from 'react'
import TodoForm from './components/TodoForm.jsx'
import TodoList from './components/TodoList.jsx'
import { createTodo, deleteTodo, getTodos, updateTodo } from './api.js'

export default function App() {
  const [todos, setTodos] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    getTodos()
      .then(setTodos)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false))
  }, [])

  const handleAdd = async (title) => {
    const todo = await createTodo(title)
    setTodos((prev) => [...prev, todo])
  }

  const handleToggle = async (id, completed) => {
    const updated = await updateTodo(id, { completed })
    setTodos((prev) => prev.map((t) => (t.id === id ? updated : t)))
  }

  const handleEdit = async (id, title) => {
    const updated = await updateTodo(id, { title })
    setTodos((prev) => prev.map((t) => (t.id === id ? updated : t)))
  }

  const handleDelete = async (id) => {
    await deleteTodo(id)
    setTodos((prev) => prev.filter((t) => t.id !== id))
  }

  const remaining = todos.filter((t) => !t.completed).length

  return (
    <div className="app">
      <h1>To-Do</h1>
      <TodoForm onAdd={handleAdd} />
      {error && <p className="error">{error}</p>}
      {loading ? (
        <p>Loading...</p>
      ) : (
        <>
          <TodoList
            todos={todos}
            onToggle={handleToggle}
            onEdit={handleEdit}
            onDelete={handleDelete}
          />
          <p className="summary">{remaining} item(s) left</p>
        </>
      )}
    </div>
  )
}
