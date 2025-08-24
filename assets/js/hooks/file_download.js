export const FileDownload = {
    mounted() {
      this.handleEvent("download_file", ({data, filename, content_type}) => {
        const blob = new Blob([data], { type: content_type })
        const url = window.URL.createObjectURL(blob)
        const link = document.createElement('a')
        link.href = url
        link.download = filename
        document.body.appendChild(link)
        link.click()
        window.URL.revokeObjectURL(url)
        document.body.removeChild(link)
      })
    }
  };