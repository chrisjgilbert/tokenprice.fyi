import { createInertiaApp } from "@inertiajs/react"
import { createRoot } from "react-dom/client"

createInertiaApp({
  // Page components live in app/javascript/pages, named after the
  // "Models/Index" identifiers the Rails controllers render.
  resolve: (name) => {
    const pages = import.meta.glob("../pages/**/*.jsx", { eager: true })
    const page = pages[`../pages/${name}.jsx`]
    if (!page) throw new Error(`Unknown Inertia page: ${name}`)
    return page
  },
  setup({ el, App, props }) {
    createRoot(el).render(<App {...props} />)
  },
})
