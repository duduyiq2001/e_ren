import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { default: String }

  connect() {
    // Show default tab or first tab
    const defaultTab = this.defaultValue || this.tabTargets[0]?.dataset.tab
    if (defaultTab) {
      this.show(defaultTab)
    }
  }

  switch(event) {
    event.preventDefault()
    const tabName = event.currentTarget.dataset.tab
    this.show(tabName)
  }

  show(tabName) {
    // Update tab styles
    this.tabTargets.forEach(tab => {
      if (tab.dataset.tab === tabName) {
        tab.classList.remove("border-transparent", "text-gray-500")
        tab.classList.add("border-washu-red", "text-washu-red")
      } else {
        tab.classList.remove("border-washu-red", "text-washu-red")
        tab.classList.add("border-transparent", "text-gray-500")
      }
    })

    // Show/hide panels
    this.panelTargets.forEach(panel => {
      if (panel.dataset.tab === tabName) {
        panel.classList.remove("hidden")
      } else {
        panel.classList.add("hidden")
      }
    })
  }
}
