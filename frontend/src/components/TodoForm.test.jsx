import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import TodoForm from './TodoForm.jsx'

describe('TodoForm', () => {
  it('submits a trimmed title and clears the input', async () => {
    const user = userEvent.setup()
    const onAdd = vi.fn().mockResolvedValue(undefined)
    render(<TodoForm onAdd={onAdd} />)

    const input = screen.getByPlaceholderText('What needs to be done?')
    await user.type(input, '  Buy milk  ')
    await user.click(screen.getByRole('button', { name: /add/i }))

    expect(onAdd).toHaveBeenCalledWith('Buy milk')
    expect(input).toHaveValue('')
  })

  it('does not submit an empty or whitespace-only title', async () => {
    const user = userEvent.setup()
    const onAdd = vi.fn()
    render(<TodoForm onAdd={onAdd} />)

    await user.type(screen.getByPlaceholderText('What needs to be done?'), '   ')
    await user.click(screen.getByRole('button', { name: /add/i }))

    expect(onAdd).not.toHaveBeenCalled()
  })
})
