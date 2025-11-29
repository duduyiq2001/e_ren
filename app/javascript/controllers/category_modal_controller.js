import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "form", "title", "id", "name", "colorPicker", "colorHex", "error"]

  connect() {
    // Sync color picker with hex input
    this.colorPickerTarget.addEventListener("input", () => {
      this.colorHexTarget.value = this.colorPickerTarget.value.toUpperCase()
    })

    this.colorHexTarget.addEventListener("input", () => {
      if (/^#[0-9A-Fa-f]{6}$/.test(this.colorHexTarget.value)) {
        this.colorPickerTarget.value = this.colorHexTarget.value
      }
    })
  }

  open(event) {
    event.preventDefault()
    const { id, name, color } = event.currentTarget.dataset

    this.errorTarget.classList.add("hidden")

    if (id) {
      this.titleTarget.textContent = "Edit Category"
      this.idTarget.value = id
      this.nameTarget.value = name || ""
      this.colorPickerTarget.value = color || "#9D2235"
      this.colorHexTarget.value = color || ""
    } else {
      this.titleTarget.textContent = "Add Category"
      this.idTarget.value = ""
      this.nameTarget.value = ""
      this.colorPickerTarget.value = "#9D2235"
      this.colorHexTarget.value = ""
    }

    this.modalTarget.classList.remove("hidden")
  }

  close(event) {
    if (event) event.preventDefault()
    this.modalTarget.classList.add("hidden")
  }

  closeOnBackdrop(event) {
    if (event.target === this.modalTarget) {
      this.close()
    }
  }

  async submit(event) {
    event.preventDefault()

    const id = this.idTarget.value
    const name = this.nameTarget.value
    const color = this.colorHexTarget.value || this.colorPickerTarget.value
    const isEdit = !!id

    const url = isEdit ? `/admin/event_categories/${id}` : "/admin/event_categories"
    const method = isEdit ? "PATCH" : "POST"

    try {
      const response = await fetch(url, {
        method: method,
        headers: {
          "Content-Type": "application/json",
          "Accept": "text/vnd.turbo-stream.html, application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({
          event_category: { name, color }
        })
      })

      if (response.ok) {
        this.close()
        // Turbo will handle the stream response, or we reload
        if (!response.headers.get("content-type")?.includes("turbo-stream")) {
          window.location.reload()
        }
      } else {
        const data = await response.json()
        this.errorTarget.textContent = data.errors ? data.errors.join(", ") : "An error occurred"
        this.errorTarget.classList.remove("hidden")
      }
    } catch (error) {
      this.errorTarget.textContent = "Network error. Please try again."
      this.errorTarget.classList.remove("hidden")
    }
  }

  async delete(event) {
    event.preventDefault()
    const { id, name } = event.currentTarget.dataset

    if (!confirm(`Are you sure you want to delete "${name}"?`)) {
      return
    }

    try {
      const response = await fetch(`/admin/event_categories/${id}`, {
        method: "DELETE",
        headers: {
          "Accept": "text/vnd.turbo-stream.html, application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        }
      })

      if (response.ok) {
        // Remove the category card from DOM
        const card = document.getElementById(`category-${id}`)
        if (card) card.remove()
      } else {
        const data = await response.json()
        alert(data.error || "Failed to delete category")
      }
    } catch (error) {
      alert("Network error. Please try again.")
    }
  }
}
