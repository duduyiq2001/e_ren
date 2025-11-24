import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    type: String,
    id: Number
  }

  async restore(event) {
    const button = event.currentTarget
    
    if (!confirm(`Are you sure you want to restore this ${this.typeValue}?`)) {
      return
    }

    // Disable button during request
    button.disabled = true
    button.textContent = 'Restoring...'
    
    try {
      const response = await fetch(`/admin/restore/${this.typeValue}/${this.idValue}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
        }
      })
      
      const data = await response.json()
      
      if (response.ok) {
        // Show success message
        this.showFlashMessage(data.message || 'Item restored successfully', 'success')
        // Reload page after a short delay
        setTimeout(() => {
          window.location.reload()
        }, 1000)
      } else {
        alert(data.error || 'Restore failed')
        button.disabled = false
        button.textContent = 'Restore'
      }
    } catch (error) {
      console.error('Error restoring:', error)
      alert('An error occurred while restoring. Please try again.')
      button.disabled = false
      button.textContent = 'Restore'
    }
  }

  showFlashMessage(message, type) {
    const flashDiv = document.createElement('div')
    flashDiv.className = `bg-${type === 'success' ? 'green' : 'red'}-50 border border-${type === 'success' ? 'green' : 'red'}-200 rounded-lg p-4 mb-6 fade-in`
    flashDiv.innerHTML = `
      <div class="flex items-center justify-between">
        <div class="flex items-center">
          <svg class="w-5 h-5 text-${type === 'success' ? 'green' : 'red'}-500 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="${type === 'success' ? 'M5 13l4 4L19 7' : 'M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z'}"></path>
          </svg>
          <span class="text-${type === 'success' ? 'green' : 'red'}-700 font-medium">${message}</span>
        </div>
        <button onclick="this.parentElement.parentElement.remove()" class="text-${type === 'success' ? 'green' : 'red'}-500 hover:text-${type === 'success' ? 'green' : 'red'}-700">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>
    `
    
    const main = document.querySelector('main')
    if (main) {
      main.insertBefore(flashDiv, main.firstChild)
    }
  }
}

