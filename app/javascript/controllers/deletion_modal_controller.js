import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    type: String,
    id: Number,
    title: String
  }

  connect() {
    this.modal = document.getElementById('deletion-modal')
    this.confirmationInput = document.getElementById('deletion-confirmation')
    this.confirmBtn = document.getElementById('confirm-delete-btn')
    
    // Enable/disable button based on confirmation
    if (this.confirmationInput) {
      this.confirmationInput.addEventListener('input', () => {
        this.updateConfirmButton()
      })
    }
  }

  open(event) {
    const button = event.currentTarget
    
    // Get data attributes - Stimulus converts kebab-case to camelCase
    // HTML: data-deletion-modal-type-value -> dataset.deletionModalTypeValue
    const typeValue = button.dataset.deletionModalTypeValue || button.getAttribute('data-deletion-modal-type-value')
    const idString = button.dataset.deletionModalIdValue || button.getAttribute('data-deletion-modal-id-value')
    const titleValue = button.dataset.deletionModalTitleValue || button.getAttribute('data-deletion-modal-title-value')
    
    // Parse ID
    const idValue = idString ? parseInt(idString, 10) : null
    
    // Debug logging
    console.log('Deletion Modal Open:', {
      type: typeValue,
      idString: idString,
      idValue: idValue,
      title: titleValue
    })
    
    // Validate ID
    if (!idValue || isNaN(idValue) || idValue <= 0) {
      console.error('Invalid ID:', {
        idString: idString,
        parsed: idValue
      })
      alert(`Error: Invalid user/event ID (${idString}). Please refresh the page.`)
      return
    }
    
    // Store values in modal element's data attributes (not Stimulus values)
    // This ensures the values persist across different controller instances
    if (this.modal) {
      this.modal.dataset.deletionId = idValue.toString()
      this.modal.dataset.deletionType = typeValue
      this.modal.dataset.deletionTitle = titleValue
      
      // Also set Stimulus values for compatibility
      this.idValue = idValue
      this.typeValue = typeValue
      this.titleValue = titleValue
    } else {
      console.error('Modal element not found')
      return
    }
    
    // Set modal title
    document.getElementById('modal-title').textContent = titleValue
    
    // Reset form
    if (this.confirmationInput) {
      this.confirmationInput.value = ''
    }
    if (document.getElementById('deletion-reason')) {
      document.getElementById('deletion-reason').value = ''
    }
    this.updateConfirmButton()
    
    // Fetch deletion preview
    this.fetchPreview()
    
    // Show modal
    this.modal.classList.remove('hidden')
  }

  close() {
    this.modal.classList.add('hidden')
  }

  updateConfirmButton() {
    if (this.confirmBtn && this.confirmationInput) {
      this.confirmBtn.disabled = this.confirmationInput.value !== 'DELETE'
    }
  }

  async fetchPreview() {
    // Get values from modal element (more reliable than Stimulus values)
    const idValue = this.modal ? parseInt(this.modal.dataset.deletionId, 10) : this.idValue
    const typeValue = this.modal ? this.modal.dataset.deletionType : this.typeValue
    
    // Validate ID before fetching
    if (!idValue || isNaN(idValue) || idValue === 0) {
      console.error('Invalid ID in fetchPreview:', { idValue, modal: this.modal?.dataset })
      this.displayPreview({})
      return
    }
    
    try {
      const type = typeValue === 'user' ? 'users' : 'event_posts'
      const url = `/admin/${type}/${idValue}/deletion_preview`
      console.log('Fetching preview:', { type, id: idValue, url })
      const response = await fetch(url, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        this.displayPreview(data.will_delete)
      } else {
        this.displayPreview({})
      }
    } catch (error) {
      console.error('Error fetching preview:', error)
      this.displayPreview({})
    }
  }

  displayPreview(preview) {
    const previewList = document.getElementById('preview-list')
    previewList.innerHTML = ''
    
    if (Object.keys(preview).length === 0) {
      previewList.innerHTML = '<li class="text-gray-500">Loading preview...</li>'
      return
    }
    
    Object.entries(preview).forEach(([key, count]) => {
      if (count > 0 || key === 'e_score') {
        const label = key.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())
        const li = document.createElement('li')
        li.textContent = `${count} ${label}`
        previewList.appendChild(li)
      }
    })
  }

  async confirmDelete() {
    if (this.confirmationInput.value !== 'DELETE') {
      alert('Please type DELETE to confirm')
      return
    }

    // Get values from modal element (more reliable than Stimulus values)
    const idValue = this.modal ? parseInt(this.modal.dataset.deletionId, 10) : this.idValue
    const typeValue = this.modal ? this.modal.dataset.deletionType : this.typeValue

    // Validate ID before making request
    if (!idValue || isNaN(idValue) || idValue === 0) {
      console.error('Invalid ID in confirmDelete:', { 
        idValue, 
        modalDataset: this.modal?.dataset,
        stimulusIdValue: this.idValue 
      })
      alert('Error: Invalid ID. Please close the modal and try again.')
      return
    }

    const type = typeValue === 'user' ? 'users' : 'event_posts'
    const reason = document.getElementById('deletion-reason').value
    const url = `/admin/${type}/${idValue}`
    
    console.log('Deleting:', { type, id: idValue, url, reason, modalDataset: this.modal?.dataset })
    
    // Disable button during request
    this.confirmBtn.disabled = true
    this.confirmBtn.textContent = 'Deleting...'
    
    try {
      const response = await fetch(url, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
        },
        body: JSON.stringify({
          confirmation: 'DELETE',
          reason: reason
        })
      })
      
      const data = await response.json()
      
      if (response.ok) {
        // Show success message
        this.showFlashMessage(data.message || 'Item deleted successfully', 'success')
        // Close modal
        this.close()
        // Reload page after a short delay
        setTimeout(() => {
          window.location.reload()
        }, 1000)
      } else {
        alert(data.error || 'Deletion failed')
        this.confirmBtn.disabled = false
        this.confirmBtn.textContent = 'Confirm Deletion'
      }
    } catch (error) {
      console.error('Error deleting:', error)
      alert('An error occurred while deleting. Please try again.')
      this.confirmBtn.disabled = false
      this.confirmBtn.textContent = 'Confirm Deletion'
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

