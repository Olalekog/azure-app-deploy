import { useState } from 'react'

export default function TodoItem({ todo, onToggle, onEdit, onDelete }) {
  const [editing, setEditing] = useState(false)
  const [draft, setDraft] = useState(todo.title)

  const commitEdit = () => {
    const trimmed = draft.trim()
    setEditing(false)
    if (trimmed && trimmed !== todo.title) {
      onEdit(todo.id, trimmed)
    } else {
      setDraft(todo.title)
    }
  }

  return (
    <li className={`todo-item ${todo.completed ? 'completed' : ''}`}>
      <input
        type="checkbox"
        checked={todo.completed}
        onChange={(e) => onToggle(todo.id, e.target.checked)}
      />
      {editing ? (
        <input
          className="edit-input"
          autoFocus
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onBlur={commitEdit}
          onKeyDown={(e) => {
            if (e.key === 'Enter') commitEdit()
            if (e.key === 'Escape') {
              setDraft(todo.title)
              setEditing(false)
            }
          }}
        />
      ) : (
        <span className="title" onDoubleClick={() => setEditing(true)}>
          {todo.title}
        </span>
      )}
      <button className="delete-btn" onClick={() => onDelete(todo.id)} aria-label="Delete todo">
        ✕
      </button>
    </li>
  )
}
