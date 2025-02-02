<script setup>
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from 'vue'
import { gsap } from 'gsap'

const images = ref([])
const selectedImage = ref(null)
const canvas = ref(null)
const canvasContainer = ref(null)
const canvasInner = ref(null)
const isDragging = ref(false)
const isResizing = ref(false)
const resizeStartPos = ref({ x: 0, y: 0 })
const leftPanelWidth = ref(50) // パーセント単位
const topPanelHeight = ref(60) // パーセント単位
const dragOffset = ref({ x: 0, y: 0 })
const currentPos = ref({ x: 0, y: 0 })
const aspectRatioLocked = ref(true)
const imgPath = ref(localStorage.getItem('imgPath') || '')
const useShortcode = ref(localStorage.getItem('useShortcode') !== 'false') // デフォルトはtrue
const backgroundColor = ref('')
const fileInput = ref(null)
const showCanvasInner = ref(true)
let canvasInnerInset = ref(50)
const targetInset = ref(0)
watch(showCanvasInner, (newValue) => { 
  targetInset.value = newValue ? 50 : 0;
  gsap.to(canvasInnerInset, { duration: 1, value: targetInset.value, ease: "none" });
});

const openFileDialog = () => {
  fileInput.value.click()
}
const handleFileSelect = (event) => {
  const files = Array.from(event.target.files)
  files.forEach(file => {
    const url = URL.createObjectURL(file)
    const path = file.path || file.name
    addImage(url, path)
  })
}
const handleDrop = (event) => {
  event.preventDefault()
  const files = Array.from(event.dataTransfer.files)
  files.forEach(file => {
    if (file.type.startsWith('image/')) {
      const url = URL.createObjectURL(file)
      const path = file.path || file.name
      addImage(url, path)
    }
  })
}
const addImage = (url, path) => {
  const newImage = {
    url,
    path,
    xBase: 'left',
    x: 0,
    xUnit: '%',
    yBase: 'top',
    y: 0,
    yUnit: '%',
    width: 0,
    widthUnit: '%',
    height: 0,
    heightUnit: 'auto',
    ratio: 1,
    repeat: 'no-repeat',
    sizeMode: 'custom',
    blendMode: 'normal'
  }  
  const index = images.value.length
  images.value.push({...newImage})
  selectedImage.value = index
  // 画像の読み込み完了後に実際のサイズを設定
  const img = new Image()
  img.onload = () => {
    newImage.ratio = img.width / img.height
    const box = canvasInner.value.getBoundingClientRect()
    // 初期サイズを設定
    if(img.width / img.height >= box.width / box.height) {
      newImage.widthUnit = '%'
      newImage.heightUnit = 'auto'
      newImage.width = unitValue(newImage,'width',box.width * 0.7,newImage.widthUnit)
    } else {
      newImage.widthUnit = 'auto'
      newImage.heightUnit = '%'
      newImage.height = unitValue(newImage,'height',box.height * 0.7,newImage.heightUnit)
    }    
    images.value[index] = {...newImage}
    // 内部値を更新（非同期処理）
    nextTick(() => {
      updateImageProperty(index, 'x', 50)
      updateImageProperty(index, 'y', 50)
    })
  }
  img.src = url
}

const startDrag = (event, index) => {
  if (event.button !== 0) return // 左クリックのみ許可
  isDragging.value = true
  selectedImage.value = index
  const image = images.value[selectedImage.value]
  const imageEl = event.target.closest('.image-container')
  if (!imageEl) return
  
  // ポインターキャプチャを開始
  event.target.setPointerCapture(event.pointerId)
  
  // クリック位置と画像の左上との差分を保存
  dragOffset.value = {
    x: event.clientX - px(image,'x',image.x,image.xUnit),
    y: event.clientY - px(image,'y',image.y,image.yUnit)
  }
  
  currentPos.value = {
    x: imageEl.offsetLeft,
    y: imageEl.offsetTop
  }
}

const startResize = (event, index, corner) => {
  if (event.button !== 0) return // 左クリックのみ許可
  isResizing.value = true
  selectedImage.value = index
  const image = images.value[selectedImage.value]
  const imageEl = event.target.closest('.image-container')
  if (!imageEl) return
  
  // ポインターキャプチャを開始
  event.target.setPointerCapture(event.pointerId)
  
  // リサイズ開始位置と方向を記録
  resizeStartPos.value = {
    x: event.clientX,
    y: event.clientY,
    width: imageEl.offsetWidth,
    height: imageEl.offsetHeight,
    corner
  }
}


const handlePointerMove = (event) => {
  const box = canvasInner.value.getBoundingClientRect() 
  const image = images.value[selectedImage.value]
  const imgCtn = document.querySelector('.image-container.selected')
  const imgEl = document.querySelector('.image-container.selected img')

  // ドラッグ処理
  if (isDragging.value && selectedImage.value !== null) {
    // 新しい位置 = マウス位置 - ドラッグ開始時のオフセット
    const newLeft = (event.clientX - dragOffset.value.x) * 1
    const newTop = (event.clientY - dragOffset.value.y) * 1

    // W=100%かつX=%の場合のみ、X方向の移動を制限
    const isWidthFull = Math.abs(px(image, 'width', image.width, image.widthUnit) - box.width) < 1
    const shouldLockX = isWidthFull && image.xUnit === '%' && image.widthUnit === '%'
    
    // H=100%かつY=%の場合のみ、Y方向の移動を制限
    const isHeightFull = Math.abs(px(image, 'height', image.height, image.heightUnit) - box.height) < 1
    const shouldLockY = isHeightFull && image.yUnit === '%' && image.heightUnit === '%'
    
    // 内部状態を更新
    if (!shouldLockX) {
      image.x = unitValue(image,'x',newLeft,image.xUnit)
    }
    if (!shouldLockY) {
      image.y = unitValue(image,'y',newTop,image.yUnit)
    }
    images.value[selectedImage.value] = {...image}
  }

  // リサイズ処理
  if (isResizing.value && selectedImage.value !== null) {
    const { corner } = resizeStartPos.value
    let newWidth, newHeight

    // コーナーに応じて計算方法を変更
    switch (corner) {
      case 'top-left':
        newWidth = Math.max(10, resizeStartPos.value.width - (event.clientX - resizeStartPos.value.x))
        newHeight = Math.max(10, resizeStartPos.value.height - (event.clientY - resizeStartPos.value.y))
        break
      case 'top-right':
        newWidth = Math.max(10, event.clientX - resizeStartPos.value.x + resizeStartPos.value.width)
        newHeight = Math.max(10, resizeStartPos.value.height - (event.clientY - resizeStartPos.value.y))
        break
      case 'bottom-left':
        newWidth = Math.max(10, resizeStartPos.value.width - (event.clientX - resizeStartPos.value.x))
        newHeight = Math.max(10, event.clientY - resizeStartPos.value.y + resizeStartPos.value.height)
        break
      case 'bottom-right':
        newWidth = Math.max(10, event.clientX - resizeStartPos.value.x + resizeStartPos.value.width)
        newHeight = Math.max(10, event.clientY - resizeStartPos.value.y + resizeStartPos.value.height)
        break
    }
    if (aspectRatioLocked.value) {
      const ratio = resizeStartPos.value.width / resizeStartPos.value.height
      newHeight = newWidth / ratio
    }

    // 単位の更新
    if (!aspectRatioLocked.value) {
      if (image.widthUnit === 'auto') {
        image.widthUnit = '%'
        // image.width = (newWidth / box.width) * 100
      }
      if (image.heightUnit === 'auto') {
        image.heightUnit = '%'
        // image.height = (newHeight / box.height) * 100
      }
    }
    
     // 内部状態を更新
    image.width = unitValue(image,'width',newWidth,image.widthUnit)
    image.height = unitValue(image,'height',newHeight,image.heightUnit)
    image.sizeMode = 'custom'

    // 最後に一度だけVue.jsの反応性を確保
    images.value[selectedImage.value] = {...image}
  }
}

const handleMouseUp = (event) => {  
  // ポインターキャプチャを解放
  if (event.target) {
    event.target.releasePointerCapture(event.pointerId)
  }
  
  isDragging.value = false
  isResizing.value = false
}

const handleKeyDown = (event) => {
  // フォーカスされている要素が入力フィールドの場合は処理をスキップ
  const activeElement = document.activeElement
  const isInputField = activeElement.tagName === 'INPUT' || 
                      activeElement.tagName === 'TEXTAREA' || 
                      activeElement.tagName === 'SELECT'
  
  if (!isInputField && event.key === 'Delete' && selectedImage.value !== null) {
    removeImage(selectedImage.value)
  }
}

const updateImageSize = () => {
  const box = canvasInner.value.getBoundingClientRect()
  images.value.forEach((image, index) => {
    const imgEl = document.querySelector(`img[src="${image.url}"]`)
    updateImageProperty(index, 'width', image.width)
    updateImageProperty(index, 'height', image.height)
    nextTick(() => {
      if(image.widthUnit === 'auto'){
        image.widthPx = imgEl.offsetWidth
        image.widthCss = cssValue(image, 'width', image.width, image.widthUnit)
      }
      if(image.heightUnit === 'auto'){
        image.heightPx = imgEl.offsetHeight
        image.heightCss = cssValue(image, 'height', image.height, image.heightUnit)
      }
    })
    console.log(image.widthCss)
    console.log(image.heightCss)
    handleSizeModeChange(image,image.sizeMode)
  })
}

// リサイズ時の処理を修正
const handleResize = () => {
  updateImageSize()
}
// マウント時にリサイズ監視を設定
onMounted(() => {
  window.addEventListener('pointermove', handlePointerMove)
  window.addEventListener('pointerup', handleMouseUp)
  window.addEventListener('keydown', handleKeyDown)
  window.addEventListener('resize', handleResize)
  
  // ResizeObserverでキャンバスコンテナのサイズ変更も監視
  const resizeObserver = new ResizeObserver(handleResize)
  if (canvasContainer.value) {
    resizeObserver.observe(canvasContainer.value)
  }
  
  document.documentElement.style.setProperty('--left-panel-width', `${leftPanelWidth.value}%`)
  document.documentElement.style.setProperty('--top-panel-height', `${topPanelHeight.value}fr`)
  document.documentElement.style.setProperty('--bottom-panel-height', `${100 - topPanelHeight.value}fr`)
})
onUnmounted(() => {
  window.removeEventListener('pointermove', handlePointerMove)
  window.removeEventListener('pointerup', handleMouseUp)
  window.removeEventListener('keydown', handleKeyDown)
  window.removeEventListener('resize', handleResize)
})

// アスペクト比固定のトグル処理
const toggleAspectRatio = (index) => {
  const image = images.value[index]
  aspectRatioLocked.value = !aspectRatioLocked.value

  if (aspectRatioLocked.value) {
    // ONにした時
    if (image.widthUnit !== 'auto' && image.heightUnit !== 'auto') {
      // 両方auto以外なら、Hをautoに
      image.heightUnit = 'auto'
    } else if (image.widthUnit === 'auto' && image.heightUnit === 'auto') {
      // 両方autoなら、Wを%に
      image.widthUnit = '%'
      const containerRect = canvasContainer.value.getBoundingClientRect()
      image.width = (image.width / containerRect.width) * 100
    }
  } else {
    // OFFにした時
    if (image.widthUnit === 'auto' || image.heightUnit === 'auto') {
      // どちらかがautoなら、両方%に
      if (image.widthUnit === 'auto') {
        handleUnitChange(index, 'width', '%')
      }
      if (image.heightUnit === 'auto') {
        handleUnitChange(index, 'height', '%')
      }
    }
  }
}

// アスペクト比固定の初期状態を計算するcomputed
const isAspectRatioLocked = computed(() => {
  if (selectedImage.value === null) return false
  const image = images.value[selectedImage.value]
  // W/Hの両方がauto以外の場合はオフ、それ以外（一方または両方がautoの場合）はオン
  return !(image.widthUnit !== 'auto' && image.heightUnit !== 'auto')
})

// 削除関数を追加
const removeImage = (index) => {
  images.value = images.value.filter((_, i) => i !== index)
  if (selectedImage.value === index) {
    selectedImage.value = null
  } else if (selectedImage.value > index) {
    selectedImage.value--
  }
}

const handleBaseChange = (index, property, isChecked) => {
  const image = {...images.value[index]}
  // 基準点のみを変更
  image[property + 'Base'] = isChecked ? 
    (property === 'x' ? 'right' : 'bottom') : 
    (property === 'x' ? 'left' : 'top')
  images.value[index] = image
}

const moveUp = () => {
  if (selectedImage.value < images.value.length - 1) {
    const temp = images.value[selectedImage.value]
    images.value[selectedImage.value] = images.value[selectedImage.value + 1]
    images.value[selectedImage.value + 1] = temp
    selectedImage.value++
  }
}
const moveDown = () => {
  if (selectedImage.value > 0) {
    const temp = images.value[selectedImage.value]
    images.value[selectedImage.value] = images.value[selectedImage.value - 1]
    images.value[selectedImage.value - 1] = temp
    selectedImage.value--
  }
}

const px = (image, property, value, unit) => {
  const box = canvasInner.value.getBoundingClientRect()
  const imgEl = document.querySelector(`img[src="${image.url}"]`)
  if(!imgEl) return 0
  if (unit === 'auto') {
    return property === 'width' ? imgEl.offsetWidth : imgEl.offsetHeight
  }
  const reverse = (property === 'x' && image.xBase === 'right') || (property === 'y' && image.yBase === 'bottom')
  let preresult, result
  if (unit === '%') {
    if (property === 'x' || property === 'y') {
      // X/Yの場合は、利用可能スペース-画像サイズを基準に計算
      const containerSize = property === 'x' ? box.width : box.height
      const imageSize = property === 'x' ? imgEl.offsetWidth : imgEl.offsetHeight
      preresult = (containerSize - imageSize) * value / 100
      result = reverse ? containerSize - preresult - imageSize : preresult
    } else if (property === 'width' || property === 'height'){
      // W/Hの場合は、キャンバスインナーサイズを基準に計算
      const containerSize = (property === 'width' ? box.width : box.height)
      result = (value / 100) * containerSize
    }
  } else if (unit === 'vw' || unit === 'vh') {
    if (property === 'x' || property === 'y') {
      // X/Yの場合は、キャンバスインナーサイズを基準に計算
      const containerSize = property === 'x' ? box.width : box.height
      const containerSize2 = unit === 'vw' ? box.width : box.height
      const imageSize = property === 'x' ? image.width : image.height
      preresult = (value / 100) * containerSize2
      result = reverse ? containerSize - preresult - imageSize : preresult
    } else if (property === 'width' || property === 'height') {
      // W/Hの場合は、キャンバスサイズを基準に計算
      const containerSize = unit === 'vw' ? box.width : box.height
      result = (value / 100) * containerSize
    }
  } else {
    // px, em, rem, ex
    const base = {
      'px': 1,
      'em': 16,
      'rem': 16,
      'ex': 8
    }
    if (property === 'x' || property === 'y') {
      const containerSize = (property === 'x' ? box.width : box.height)
      const imageSize = property === 'x' ? image.width : image.height
      preresult = value * (base[unit] || 1)
      result = reverse ? containerSize - preresult - imageSize : preresult
    } else if (property === 'width' || property === 'height') {
      result = value * (base[unit] || 1)
    }
  }
  return result
}


// 単位変換関数
const unitValue = (image, property, pixelValue, unit) => {
  const canvas = canvasContainer.value.getBoundingClientRect()
  const box = canvasInner.value.getBoundingClientRect()
  const imgEl = document.querySelector(`img[src="${image.url}"]`)
  if (unit === 'auto') return unit
  const reverse = (property === 'x' && image.xBase === 'right') || (property === 'y' && image.yBase === 'bottom')
  let preresult, result
  if (unit === '%') {
    if (property === 'x' || property === 'y') {
      // X/Yの場合は、利用可能スペースに対する相対位置として計算
      const containerSize = property === 'x' ? box.width : box.height
      const imageSize = property === 'x' ? imgEl.offsetWidth : imgEl.offsetHeight
      preresult = reverse ? containerSize - pixelValue - imageSize : pixelValue
      result = preresult / (containerSize - imageSize) * 100
    } else {
      // W/Hの場合は、キャンバスインナーサイズを基準に計算
      const containerSize = property === 'width' ? box.width : box.height
      result = pixelValue / containerSize * 100
    }
  } else if (unit === 'vw' || unit === 'vh') {
    if (property === 'x' || property === 'y') {
      // X/Yの場合は、キャンバスインナーサイズを基準に計算
      const containerSize = property === 'x' ? box.width : box.height
      const containerSize2 = unit === 'vw' ? box.width : box.height
      const imageSize = property === 'x' ? image.width : image.height
      preresult = reverse ? containerSize - pixelValue - imageSize : pixelValue
      result = preresult / containerSize2 * 100
    } else if (property === 'width' || property === 'height') {
      // W/Hの場合は、キャンバスサイズを基準に計算
      const containerSize = (unit === 'vw' ? canvas.width : canvas.height)
      result = pixelValue / containerSize * 100
    }
  } else {
    // px, em, rem, ex
    const base = {
      'px': 1,
      'em': 16,
      'rem': 16,
      'ex': 8
    }
    if (property === 'x' || property === 'y') {
      const containerSize = property === 'x' ? box.width : box.height
      const imageSize = property === 'x' ? image.width : image.height
      preresult = reverse ? containerSize - pixelValue - imageSize : pixelValue
      result = (preresult / (base[unit] || 1))
    } else if (property === 'width' || property === 'height') {
      result = (pixelValue / (base[unit] || 1))
    }
  }
  return result
}

// 表示用の値を計算する関数を修正
const displayValue = (image, property) => {
  let value = image[property]
  if (image[property + 'Unit'] === 'auto') {
    return ''
  } else {
    return Math.round(value)
  }
}

const cssValue = (image, property,value, unit) => {
  const imgEl = document.querySelector(`img[src="${image.url}"]`)
  if (unit === 'auto') {
    if(property === 'width') {
      return (image.heightUnit === 'auto' ? imgEl.naturalWidth : px(image, 'height', image.height, image.heightUnit) * image.ratio) + 'px'
    } else if(property === 'height') {
      return (image.widthUnit === 'auto' ? imgEl.naturalHeight : px(image, 'width', image.width, image.widthUnit) / image.ratio) + 'px'
    }
    return "auto"
  } else if (unit === 'vw') {
    return value + 'cqw'
  } else if (unit === 'vh') {
    return value + 'cqh'
  } else { 
    return value + unit
  }
}

const updateImageProperty = (index, property, value) => {
  const image = {...images.value[index]}
  const css = cssValue(Number(value), image[property + 'Unit'])
  image[property] = value
  image[property+'Css'] = css
  images.value[index] = image
}

// W/HのUnit変更を監視して、アスペクト比固定の状態を更新
watch(
  () => selectedImage.value !== null ? 
    [images.value[selectedImage.value].widthUnit, 
     images.value[selectedImage.value].heightUnit] : 
    null,
  () => {
    if (selectedImage.value === null) return
    // 現在の表示状態を取得
    const shouldBeLocked = isAspectRatioLocked.value
    // 実際の状態を表示状態に合わせる
    if (aspectRatioLocked.value !== shouldBeLocked) {
      aspectRatioLocked.value = shouldBeLocked
    }
  }
)

const handleUnitChange = (index, property, newUnit) => {
  if (index === null || index >= images.value.length) return  
  const image = {...images.value[index]}
  const container = canvasContainer.value
  const imgEl = document.querySelector(`img[src="${image.url}"]`)
  const pxValue = image[property + 'Px']
  const newValue = unitValue(image, property, pxValue, newUnit)
  // 単位を更新
  image[property + 'Unit'] = newUnit
  updateImageProperty(index, property, newValue)
}

const resetProperty = (property) => {
  if (selectedImage.value === null) return
  const container = canvasContainer.value
  if (!container) return
  const rect = container.getBoundingClientRect()
  
  const defaults = {
    x: { value: (rect.width - rect.width * 0.3) / 2, unit: '%' },  // 中央に配置
    y: { value: (rect.height - (rect.width * 0.3) * (images.value[selectedImage.value].height / images.value[selectedImage.value].width)) / 2, unit: '%' },  // 中央に配置
    width: { value: rect.width * 0.3, unit: '%' },  // コンテナの30%相当
    height: { value: (rect.width * 0.3) * (images.value[selectedImage.value].height / images.value[selectedImage.value].width), unit: 'auto' },  // アスペクト比を維持
    repeat: 'no-repeat',
    sizeMode: 'custom'
  }
  
  const image = {...images.value[selectedImage.value]}
  
  if (property in defaults) {
    if (typeof defaults[property] === 'object') {
      image[property] = defaults[property].value
      image[property + 'Unit'] = defaults[property].unit
    } else {
      image[property] = defaults[property]
    }
    images.value[selectedImage.value] = image
  }
}

const handleSizeModeChange = (image, newmode) => {
  const mode = newmode ? newmode : image.sizeMode
  const box = canvasInner.value.getBoundingClientRect()
  const isWideImage = image.ratio > box.width / box.height    
  if (mode === 'contain') {
    if (isWideImage) {
      // 横長画像の場合
      image.widthUnit = '%'
      image.width = 100
      image.heightUnit = 'auto'
    } else {
      // 縦長画像の場合
      image.heightUnit = '%'
      image.height = 100
      image.widthUnit = 'auto'
    }
  } else if (mode === 'cover') {
    if (isWideImage) {
      // 横長画像の場合
      image.heightUnit = '%'
      image.height = 100
      image.widthUnit = 'auto'
    } else {
      // 縦長画像の場合
      image.widthUnit = '%'
      image.width = 100
      image.heightUnit = 'auto'
    }
  }
  updateImageProperty(selectedImage.value, 'width', image.width)
  updateImageProperty(selectedImage.value, 'height', image.height)
}

watch(() => images.value.map(image => ({
  x: image.x,
  y: image.y,
  width: image.width,
  height: image.height
})), (newValues) => {
  const box = canvasContainer.value.getBoundingClientRect()
  images.value.forEach((image, index) => {
    image.xPx = px(image, 'x', image.x, image.xUnit)
    image.yPx = px(image, 'y', image.y, image.yUnit)
    image.widthPx = px(image, 'width', image.width, image.widthUnit)
    image.heightPx = px(image, 'height', image.height, image.heightUnit)
    image.xCss = cssValue(image, 'x', image.x, image.xUnit)
    image.yCss = cssValue(image, 'y', image.y, image.yUnit)
    image.widthCss = cssValue(image, 'width', image.width, image.widthUnit)
    image.heightCss = cssValue(image, 'height', image.height, image.heightUnit)
  })
}, { deep: true })


watch(canvasInnerInset, (newValue) => {
  nextTick(() => {
    updateImageSize();
  })
})

// LocalStorageに保存する関数を追加
watch(imgPath, (newValue) => {
  localStorage.setItem('imgPath', newValue)
})

watch(useShortcode, (newValue) => {
  localStorage.setItem('useShortcode', newValue)
})

// 表示用のフォーマット関数を修正
const formatDisplayValue = (value, unit) => {
  if (unit === 'center' || unit === 'auto') return unit
  if (value === '') return ''
  return `${value}${unit}`
}

const generatedCSS = computed(() => {
  if (!canvasContainer.value) return ''
  const containerRect = canvasContainer.value.getBoundingClientRect()
  
  const bgImages = [...images.value].reverse().map(img => {
    // X座標の計算
    const xValue = displayValue(img, 'x')
    const isWidthFull = Math.abs(img.width - containerRect.width) < 1 && img.widthUnit === '%'
    const x = img.xUnit === 'center' || xValue === 50 && img.xUnit === '%' || (isWidthFull && xValue === 0)  ? 'center' :
             img.xBase === 'right' ? 
               (xValue === 0 ? 'right' : xValue === 100 && img.xUnit === '%' ? 'left' : `right ${xValue}${img.xUnit}`) :
               (xValue === 0 ? 'left' : xValue === 100 && img.xUnit === '%' ? 'right' : `${xValue}${img.xUnit}`)
    
    // Y座標の計算
    const yValue = displayValue(img, 'y')
    const isHeightFull = Math.abs(img.height - containerRect.height) < 1 && img.heightUnit === '%'
    const y = img.yUnit === 'center' || yValue === 50 && img.yUnit === '%' || (isHeightFull && yValue === 0) ? 'center' :
             img.yBase === 'bottom' ? 
               (yValue === 0 ? 'bottom' : yValue === 100 && img.yUnit === '%' ? 'top' : `bottom ${yValue}${img.yUnit}`) :
               (yValue === 0 ? 'top' : yValue === 100 && img.yUnit === '%' ? 'bottom' : `${yValue}${img.yUnit}`)
    
    // サイズの計算
    const widthValue = displayValue(img, 'width')
    const heightValue = displayValue(img, 'height')
    let width = img.widthUnit === 'auto' ? 'auto' : `${widthValue}${img.widthUnit}`
    let height = img.heightUnit === 'auto' ? 'auto' : `${heightValue}${img.heightUnit}`
    
    let size
    if (img.sizeMode === 'custom') {
      if (width === 'auto' && height === 'auto') {
        size = 'auto'
      } else if (height === 'auto') {
        size = width
      } else if (width === 'auto') {
        size = `auto ${height}`
      } else {
        size = `${width} ${height}`
      }
    } else {
      size = img.sizeMode
    }
    
    // position と size を組み合わせ
    let position
    if (x === 'center' && y === 'center') {
      position = 'center'
    } else {
      const xPos = x === 'left' ? 'left' : x === 'right' ? 'right' : x
      const yPos = y === 'top' ? 'top' : y === 'bottom' ? 'bottom' : y
      position = `${xPos} ${yPos}`
    }

    const fullPath = imgPath.value + img.path
    
    if (useShortcode.value) {
      return `url("${fullPath}") ${img.repeat !== 'repeat' ? `${img.repeat} ` : ''}${position} / ${size}`
    } else {
      return {
        url: fullPath,
        repeat: img.repeat,
        position,
        size,
        blendMode: img.blendMode
      }
    }
  })

  if (useShortcode.value) {
    const bgString = bgImages.join(',\n    ')
    const blendModes = [...images.value]
      .reverse()
      .map(img => img.blendMode)
      .filter(mode => mode !== 'normal')

    const bgColor = (backgroundColor.value ? (bgImages.length>0 ? ' ' : '') + `${backgroundColor.value}` : '')
    return `background:${bgImages.length>1 ? '\n    ' : bgImages.length>0 || backgroundColor.value ? ' ' : ' none'}${bgString}${bgColor};${
      blendModes.length > 0 ? `\nbackground-blend-mode: ${blendModes.join(', ')};` : ''
    }`
  } else {
    const urls = bgImages.map(bg => `url("${bg.url}")`).join(', ')
    const repeats = bgImages.map(bg => bg.repeat).join(', ')
    const positions = bgImages.map(bg => bg.position).join(', ')
    const sizes = bgImages.map(bg => bg.size).join(', ')
    const blendModes = bgImages.map(bg => bg.blendMode).filter(mode => mode !== 'normal').join(', ')

    return `background-image: ${urls};${
      repeats !== 'repeat' ? `\nbackground-repeat: ${repeats};` : ''
    }\nbackground-position: ${positions};\nbackground-size: ${sizes};${
      backgroundColor.value ? `\nbackground-color: ${backgroundColor.value};` : ''
    }${
      blendModes ? `\nbackground-blend-mode: ${blendModes};` : ''
    }`
  }
})

const copyToClipboard = () => {
  navigator.clipboard.writeText(generatedCSS.value)
}

</script>

<template>
  <div class="app-container">
    <div class="top-panel">
      <div class="canvas-container" 
        ref="canvasContainer"
        @dragover.prevent 
        @drop.prevent="handleDrop"
        @pointerup.prevent="handleMouseUp"
        @click="selectedImage = null"
      >
        <div class="canvas-control-group">
          <button class="add-image-button" @click="openFileDialog">
            <span class="plus-icon">+</span>
            Add Image
          </button>
          <label class="checkbox-wrapper">
            <input 
              type="checkbox" 
              :checked="showCanvasInner"
              @change="e => {
                showCanvasInner = e.target.checked
              }"
            > 
            <span>Inner</span>
          </label>
        </div>
        <input 
          type="file" 
          ref="fileInput" 
          @change="handleFileSelect" 
          accept="image/*" 
          multiple 
          style="display: none"
        >
        <h1>Multiple Background CSS Generator</h1>
        <p class="logo"><a href="https://tomippe.jp/" target="_blank"><img src="https://apps.tomippe.jp/logo.svg" alt="Studio Tomippe"></a></p>
        <div class="canvas" ref="canvas">
          <div class="canvas-inner"
          ref="canvasInner"
          :style="{
            backgroundColor: backgroundColor,
            inset: `${canvasInnerInset}px`
          }">
            <template v-for="(image, index) in images" :key="index">
              <div 
                class="image-container"
                :class="{ selected: selectedImage === index }"
                :style="{
                  position: 'absolute',
                  left: image.xBase === 'right' ? 'auto' : image.xCss,
                  right: image.xBase !== 'right' ? 'auto' : image.xCss,
                  top: image.yBase === 'bottom' ? 'auto' : image.yCss,
                  bottom: image.yBase !== 'bottom' ? 'auto' : image.yCss,
                  transform: `${image.xUnit ==='%' ? 'translateX(calc(calc('+image.xCss+') * '+ (image.xBase === 'right' ? '1' : '-1') +'))' : 'translateX(0)'} ${image.yUnit ==='%' ? 'translateY(calc(calc('+image.yCss+') * '+ (image.yBase === 'bottom' ? '1' : '-1') +'))' : 'translateY(0)'}`,
                  width: `${image.widthCss} !important`,
                  height: `${image.heightCss} !important`,
                  zIndex: index,
                  '--blend-mode': image.blendMode
                }"
                @pointerdown.prevent="startDrag($event, index)"
                @click.stop
              >
                <div 
                  class="tile-container" 
                  v-if="image.repeat !== 'no-repeat'"
                >
                  <div 
                    class="tile-overlay"
                    :style="{
                      backgroundImage: `url(${image.url})`,
                      backgroundRepeat: image.repeat,
                      backgroundSize: (image.widthUnit ==='%' ? 'calc(100% / 201)' : image.widthCss) + ' ' + (image.heightUnit ==='%' ? 'calc(100% / 201)' : image.heightCss)
                    }"
                  ></div>
                </div>
                <div class="main-image"
                  :style="{
                    position: 'relative'
                  }"
                >
                  <img 
                    :src="image.url" 
                    draggable="false"
                  >
                </div>
                <div class="bounding-box">
                  <div class="coordinates" v-show="isDragging || isResizing">
                    x: {{ formatDisplayValue(displayValue(image, 'x'), image.xUnit) }}, 
                    y: {{ formatDisplayValue(displayValue(image, 'y'), image.yUnit) }}
                    w: {{ formatDisplayValue(displayValue(image, 'width'), image.widthUnit) }}, 
                    h: {{ formatDisplayValue(displayValue(image, 'height'), image.heightUnit) }}
                  </div>
                  <button 
                    class="delete-button"
                    @click.prevent.stop="removeImage(index)"
                  >×</button>
                  <div 
                    class="resize-handle top-left"
                    @pointerdown.prevent.stop="startResize($event, index, 'top-left')"
                  ></div>
                  <div 
                    class="resize-handle bottom-left"
                    @pointerdown.prevent.stop="startResize($event, index, 'bottom-left')"
                  ></div>
                  <div 
                    class="resize-handle bottom-right"
                    @pointerdown.prevent.stop="startResize($event, index, 'bottom-right')"
                  ></div>
                  <button 
                    class="aspect-ratio-lock"
                    @click.prevent.stop="toggleAspectRatio(index)"
                    :class="{ locked: aspectRatioLocked }"
                    title="Lock aspect ratio"
                  >⛓</button>
                </div>
              </div>
            </template>
          </div>
        </div>
      </div>
    </div>

    <div class="bottom-panel">
      <div class="image-controls">
        <div class="control-groups" v-if="selectedImage !== null">
          <div class="layer-controls">
            <button @click="moveUp" :disabled="selectedImage === images.length - 1">Front(前面へ)</button>
            <button @click="moveDown" :disabled="selectedImage === 0">Back(背面へ)</button>
          </div>
          <div class="control-group">
            <label>X:</label>
            <label class="checkbox-wrapper">
              <input 
                type="checkbox" 
                :checked="images[selectedImage].xBase === 'right'"
                @change="e => handleBaseChange(selectedImage, 'x', e.target.checked)"
              >
              <span>right</span>
            </label>
            <div class="input-wrapper">
              <div class="quick-buttons" v-if="images[selectedImage].xUnit === '%'">
                <button @click="updateImageProperty(selectedImage, 'x', 0)"
                :disabled="(Math.abs(images[selectedImage].widthPx - canvasInner.getBoundingClientRect().width) < 1 && 
                            images[selectedImage].xUnit === '%' && 
                            images[selectedImage].widthUnit === '%')">{{images[selectedImage].xBase === 'right' ? 'right' : 'left'}}</button>
                <button @click="updateImageProperty(selectedImage, 'x', 50)"
                :disabled="(Math.abs(images[selectedImage].widthPx - canvasInner.getBoundingClientRect().width) < 1 && 
                            images[selectedImage].xUnit === '%' && 
                            images[selectedImage].widthUnit === '%')">center</button>
                <button @click="updateImageProperty(selectedImage, 'x', 100)"
                :disabled="images[selectedImage].xUnit === 'auto' || 
                          images[selectedImage].xUnit === 'center' || 
                          (Math.abs(images[selectedImage].widthPx - canvasInner.getBoundingClientRect().width) < 1 && 
                            images[selectedImage].xUnit === '%' && 
                            images[selectedImage].widthUnit === '%')">{{images[selectedImage].xBase === 'right' ? 'left' : 'right'}}</button>
              </div>
              <div class="quick-buttons" v-if="['vw', 'vh'].includes(images[selectedImage].xUnit)">
                <button @click="updateImageProperty(selectedImage, 'x', 0)">{{images[selectedImage].xBase === 'right' ? 'right' : 'left'}}</button>
                <button @click="updateImageProperty(selectedImage, 'x', 50)">50</button>
              </div>
              <div class="quick-buttons" v-if="images[selectedImage].xUnit === 'px'">
                <button @click="updateImageProperty(selectedImage, 'x', 0)">{{images[selectedImage].xBase === 'right' ? 'right' : 'left'}}</button>
                <button @click="updateImageProperty(selectedImage, 'x', 10)">10</button>
                <button @click="updateImageProperty(selectedImage, 'x', 100)">100</button>
                <button @click="updateImageProperty(selectedImage, 'x', 1000)">1000</button>
              </div>
              <div class="quick-buttons" v-if="['em', 'rem', 'ex'].includes(images[selectedImage].xUnit)">
                <button @click="updateImageProperty(selectedImage, 'x', 0)">{{images[selectedImage].xBase === 'right' ? 'right' : 'left'}}</button>
                <button @click="updateImageProperty(selectedImage, 'x', 1)">1</button>
                <button @click="updateImageProperty(selectedImage, 'x', 10)">10</button>
              </div>
              <input 
                type="number" 
                :value="displayValue(images[selectedImage], 'x')"
                :disabled="images[selectedImage].xUnit === 'auto' || 
                          images[selectedImage].xUnit === 'center' || 
                          (Math.abs(images[selectedImage].widthPx - canvasInner.getBoundingClientRect().width) < 1 && 
                            images[selectedImage].xUnit === '%' && 
                            images[selectedImage].widthUnit === '%')"
                @keydown="e => {
                  if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
                    const value = Number(e.target.value)
                    const newValue = e.key === 'ArrowUp' ? value + 1 : value - 1
                    updateImageProperty(selectedImage, 'x', newValue)
                    e.preventDefault()
                  }
                }"
                @input="e => updateImageProperty(selectedImage, 'x', e.target.value)"
                step="1"
              >
            </div>
            <select v-model="images[selectedImage].xUnit" @change="e => handleUnitChange(selectedImage, 'x', e.target.value)">
              <option value="%">%</option>
              <option value="px">px</option>
              <option value="vw">vw</option>
              <option value="vh">vh</option>
              <option value="em">em</option>
              <option value="rem">rem</option>
              <option value="ex">ex</option>
            </select>
            <button class="reset" @click="resetProperty('x')">↺</button>
          </div>
          <div class="control-group">
            <label>Y:</label>
            <label class="checkbox-wrapper">
              <input 
                type="checkbox" 
                :checked="images[selectedImage].yBase === 'bottom'"
                @change="e => handleBaseChange(selectedImage, 'y', e.target.checked)"
              >
              <span>bottom</span>
            </label>
            <div class="input-wrapper">
              <div class="quick-buttons" v-if="images[selectedImage].yUnit === '%'">                
                <button @click="updateImageProperty(selectedImage, 'y', 0)"
                :disabled="(Math.abs(images[selectedImage].heightPx - canvasInner.getBoundingClientRect().height) < 1 && 
                            images[selectedImage].heightUnit === '%')">{{images[selectedImage].yBase === 'bottom' ? 'bottom' : 'top'}}</button>
                <button @click="updateImageProperty(selectedImage, 'y', 50)"
                :disabled="(Math.abs(images[selectedImage].heightPx - canvasInner.getBoundingClientRect().height) < 1 && 
                            images[selectedImage].heightUnit === '%')">center</button>
                <button @click="updateImageProperty(selectedImage, 'y', 100)"
                :disabled="(Math.abs(images[selectedImage].heightPx - canvasInner.getBoundingClientRect().height) < 1 && 
                            images[selectedImage].heightUnit === '%')">{{images[selectedImage].yBase === 'bottom' ? 'top' : 'bottom'}}</button>
              </div>
              <div class="quick-buttons" v-if="['vw', 'vh'].includes(images[selectedImage].yUnit)">
                <button @click="updateImageProperty(selectedImage, 'y', 0)">{{images[selectedImage].yBase === 'bottom' ? 'bottom' : 'top'}}</button>
                <button @click="updateImageProperty(selectedImage, 'y', 50)">50</button>
              </div>
              <div class="quick-buttons" v-if="images[selectedImage].yUnit === 'px'">
                <button @click="updateImageProperty(selectedImage, 'y', 0)">{{images[selectedImage].yBase === 'bottom' ? 'bottom' : 'top'}}</button>
                <button @click="updateImageProperty(selectedImage, 'y', 10)">10</button>
                <button @click="updateImageProperty(selectedImage, 'y', 100)">100</button>
                <button @click="updateImageProperty(selectedImage, 'y', 1000)">1000</button>
              </div>
              <div class="quick-buttons" v-if="['em', 'rem', 'ex'].includes(images[selectedImage].yUnit)">
                <button @click="updateImageProperty(selectedImage, 'y', 0)">{{images[selectedImage].yBase === 'bottom' ? 'bottom' : 'top'}}</button>
                <button @click="updateImageProperty(selectedImage, 'y', 1)">1</button>
                <button @click="updateImageProperty(selectedImage, 'y', 10)">10</button>
              </div>
              <input 
                type="number" 
                :value="displayValue(images[selectedImage], 'y')"
                :disabled="images[selectedImage].yUnit === 'auto' || 
                          images[selectedImage].yUnit === 'center' || 
                          (Math.abs(images[selectedImage].heightPx - canvasInner.getBoundingClientRect().height) < 1 && 
                            images[selectedImage].yUnit === '%' && 
                            images[selectedImage].heightUnit === '%')"
                @keydown="e => {
                  if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
                    const value = Number(e.target.value)
                    const newValue = e.key === 'ArrowUp' ? value + 1 : value - 1
                    updateImageProperty(selectedImage, 'y', newValue)
                    e.preventDefault()
                  }
                }"
                @input="e => updateImageProperty(selectedImage, 'y', e.target.value)"
                step="1"
              >
            </div>
            <select v-model="images[selectedImage].yUnit" @change="e => handleUnitChange(selectedImage, 'y', e.target.value)">
              <option value="%">%</option>
              <option value="px">px</option>
              <option value="vw">vw</option>
              <option value="vh">vh</option>
              <option value="em">em</option>
              <option value="rem">rem</option>
              <option value="ex">ex</option>
            </select>
            <button class="reset" @click="resetProperty('y')">↺</button>
          </div>
          <div class="control-group">
            <label>Size:</label>
            <div class="radio-group" style="grid-column: 2 / 5;">
              <label>
                <input type="radio" v-model="images[selectedImage].sizeMode" value="custom" name="sizeMode" @click="handleSizeModeChange(images[selectedImage],'custom')">
                custom
              </label>
              <label>
                <input type="radio" v-model="images[selectedImage].sizeMode" value="contain" name="sizeMode" @click="handleSizeModeChange(images[selectedImage],'contain')">
                contain
              </label>
              <label>
                <input type="radio" v-model="images[selectedImage].sizeMode" value="cover" name="sizeMode" @click="handleSizeModeChange(images[selectedImage],'cover')">
                cover
              </label>
            </div>
          </div>
          <div class="control-group">
            <label>W:</label>
            <div class="checkbox-wrapper"></div>
            <div class="input-wrapper">
              <div class="quick-buttons" v-if="['%', 'vw', 'vh'].includes(images[selectedImage].widthUnit)">
                <button @click="updateImageProperty(selectedImage, 'width', 10)" :disabled="images[selectedImage].sizeMode === 'contain' || images[selectedImage].sizeMode === 'cover'">10</button>
                <button @click="updateImageProperty(selectedImage, 'width', 30)" :disabled="images[selectedImage].sizeMode === 'contain' || images[selectedImage].sizeMode === 'cover'">30</button>
                <button @click="updateImageProperty(selectedImage, 'width', 50)" :disabled="images[selectedImage].sizeMode === 'contain' || images[selectedImage].sizeMode === 'cover'">50</button>
                <button @click="e =>{
                  updateImageProperty(selectedImage, 'width', 100)
                  if(images[selectedImage].widthUnit === '%' && images[selectedImage].xUnit === '%'){
                      updateImageProperty(selectedImage, 'x', 0)
                  }
                }" :disabled="images[selectedImage].sizeMode === 'contain' || images[selectedImage].sizeMode === 'cover'">100</button>
              </div>
              <div class="quick-buttons" v-if="images[selectedImage].widthUnit === 'px'">
                <button @click="updateImageProperty(selectedImage, 'width', 10)">10</button>
                <button @click="updateImageProperty(selectedImage, 'width', 100)">100</button>
                <button @click="updateImageProperty(selectedImage, 'width', 1000)">1000</button>
              </div>
              <div class="quick-buttons" v-if="['em', 'rem', 'ex'].includes(images[selectedImage].widthUnit)">
                <button @click="updateImageProperty(selectedImage, 'width', 1)">1</button>
                <button @click="updateImageProperty(selectedImage, 'height', 10)">10</button>
              </div>
              <input 
                type="number" 
                :value="images[selectedImage].widthUnit === 'auto' ? '' : displayValue(images[selectedImage], 'width')"
                :disabled="images[selectedImage].sizeMode === 'contain' || images[selectedImage].sizeMode === 'cover' || images[selectedImage].widthUnit === 'auto'"
                @keydown="e => {
                  if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
                    const value = Number(e.target.value)
                    const newValue = e.key === 'ArrowUp' ? value + 1 : value - 1
                    updateImageProperty(selectedImage, 'width', newValue)
                    if(newValue == 100 && images[selectedImage].widthUnit === '%' && images[selectedImage].xUnit === '%'){
                      updateImageProperty(selectedImage, 'x', 0)
                    }
                    e.preventDefault()
                  }
                }"
                @input="e => {
                  updateImageProperty(selectedImage, 'width', e.target.value)
                  images[selectedImage].sizeMode = 'custom'
                  if(e.target.value == 100 && images[selectedImage].widthUnit === '%' && images[selectedImage].xUnit === '%'){
                    updateImageProperty(selectedImage, 'x', 0)
                  }
                }"
                step="1"
              >
            </div>
            <select v-model="images[selectedImage].widthUnit" @change="e => handleUnitChange(selectedImage, 'width', e.target.value)" :disabled="(images[selectedImage].sizeMode === 'contain' || images[selectedImage].sizeMode === 'cover')">
              <option value="auto">auto</option>
              <option value="%">%</option>
              <option value="px">px</option>
              <option value="vw">vw</option>
              <option value="vh">vh</option>
              <option value="svw">svw</option>
              <option value="em">em</option>
              <option value="rem">rem</option>
              <option value="ex">ex</option>
            </select>
            <button class="reset" @click="resetProperty('width')">↺</button>
          </div>
          <div class="control-group">
            <label>H:</label>
            <div class="checkbox-wrapper"></div>
            <div class="input-wrapper">
              <div class="quick-buttons" v-if="['%', 'vw', 'vh'].includes(images[selectedImage].heightUnit)">
                <button @click="updateImageProperty(selectedImage, 'height', 10)" :disabled="images[selectedImage].sizeMode === 'contain' || images[selectedImage].sizeMode === 'cover'">10</button>
                <button @click="updateImageProperty(selectedImage, 'height', 30)" :disabled="images[selectedImage].sizeMode === 'contain' || images[selectedImage].sizeMode === 'cover'">30</button>
                <button @click="updateImageProperty(selectedImage, 'height', 50)" :disabled="images[selectedImage].sizeMode === 'contain' || images[selectedImage].sizeMode === 'cover'">50</button>
                <button @click="e => {
                updateImageProperty(selectedImage, 'height', 100)
                if(images[selectedImage].heightUnit === '%' && images[selectedImage].yUnit === '%'){
                    updateImageProperty(selectedImage, 'y', 0)
                }
                }" :disabled="images[selectedImage].sizeMode === 'contain' || images[selectedImage].sizeMode === 'cover'">100</button>
              </div>
              <div class="quick-buttons" v-if="images[selectedImage].heightUnit === 'px'">
                <button @click="updateImageProperty(selectedImage, 'height', 10)">10</button>
                <button @click="updateImageProperty(selectedImage, 'height', 100)">100</button>
                <button @click="updateImageProperty(selectedImage, 'height', 1000)">1000</button>
              </div>
              <div class="quick-buttons" v-if="['em', 'rem', 'ex'].includes(images[selectedImage].heightUnit)">
                <button @click="updateImageProperty(selectedImage, 'height', 1)">1</button>
                <button @click="updateImageProperty(selectedImage, 'height', 10)">10</button>
              </div>
              <input 
                type="number" 
                :value="images[selectedImage].heightUnit === 'auto' ? '' : displayValue(images[selectedImage], 'height')"
                :disabled="images[selectedImage].sizeMode === 'contain' || images[selectedImage].sizeMode === 'cover' || images[selectedImage].heightUnit === 'auto'"
                @keydown="e => {
                  if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
                    const value = Number(e.target.value)
                    const newValue = e.key === 'ArrowUp' ? value + 1 : value - 1
                    updateImageProperty(selectedImage, 'height', newValue)
                    if(newValue == 100 && images[selectedImage].heightUnit === '%' && images[selectedImage].yUnit === '%'){
                      updateImageProperty(selectedImage, 'y', 0)
                    }
                    e.preventDefault()
                  }
                }"
                @input="e => {
                  updateImageProperty(selectedImage, 'height', e.target.value)
                  images[selectedImage].sizeMode = 'custom'
                  if(e.target.value == 100 && images[selectedImage].heightUnit === '%' && images[selectedImage].yUnit === '%'){
                    updateImageProperty(selectedImage, 'y', 0)
                  }
                }"
                step="1"
              >
            </div>
            <select v-model="images[selectedImage].heightUnit" @change="e => handleUnitChange(selectedImage, 'height', e.target.value)" :disabled="(images[selectedImage].sizeMode === 'contain' || images[selectedImage].sizeMode === 'cover')">
              <option value="auto">auto</option>
              <option value="%">%</option>
              <option value="px">px</option>
              <option value="vw">vw</option>
              <option value="vh">vh</option>
              <option value="em">em</option>
              <option value="rem">rem</option>
              <option value="ex">ex</option>
            </select>
            <button class="reset" @click="resetProperty('height')">↺</button>
          </div>
          <div class="control-group">
            <label>Repeat:</label>
            <select v-model="images[selectedImage].repeat" style="grid-column: 2 / 4">
              <option value="no-repeat">no-repeat</option>
              <option value="repeat">repeat</option>
              <option value="repeat-x">repeat-x</option>
              <option value="repeat-y">repeat-y</option>
            </select>
            <button class="reset" @click="resetProperty('repeat')">↺</button>
          </div>
          <div class="control-group">
            <label>Blend:</label>
            <select v-model="images[selectedImage].blendMode" style="grid-column: 2 / 4">
              <option value="normal">normal</option>
              <option value="multiply">multiply</option>
              <option value="screen">screen</option>
              <option value="overlay">overlay</option>
              <option value="darken">darken</option>
              <option value="lighten">lighten</option>
              <option value="color-dodge">color-dodge</option>
              <option value="color-burn">color-burn</option>
              <option value="hard-light">hard-light</option>
              <option value="soft-light">soft-light</option>
              <option value="difference">difference</option>
              <option value="exclusion">exclusion</option>
              <option value="hue">hue</option>
              <option value="saturation">saturation</option>
              <option value="color">color</option>
              <option value="luminosity">luminosity</option>
            </select>
            <button class="reset" @click="resetProperty('blendMode')">↺</button>
          </div>
          <!-- <div class="control-group">
            <label>Lock:</label>
            <div class="checkbox-wrapper">
              <input 
                type="checkbox" 
                :checked="isAspectRatioLocked"
                @change="e => toggleAspectRatio(selectedImage)"
              >
              <span>Aspect Ratio</span>
            </div>
          </div> -->
        </div>
        <div class="control-groups" v-else>
          <div v-if="images.length > 0">
            <div class="layer-list">
              <div 
                v-for="(image, index) in [...images].reverse()" 
                :key="index"
                class="layer-item"
                :class="{ selected: selectedImage === images.length - 1 - index }"
                @click="selectedImage = images.length - 1 - index"
              >
                <img :src="image.url" class="layer-thumbnail">
                <span class="layer-name">{{ (image.path || '').split('/').pop() || 'Untitled' }}</span>
                <div class="layer-buttons">
                  <button 
                    class="layer-button"
                    @click.stop="() => {
                      selectedImage = images.length - 1 - index
                      moveUp(images.length - 1 - index)
                      selectedImage = null
                    }"
                    :disabled="index === 0"
                  >▲</button>
                  <button 
                    class="layer-button"
                    @click.stop="() => {
                      selectedImage = images.length - 1 - index
                      moveDown(images.length - 1 - index)
                      selectedImage = null
                    }"
                    :disabled="index === images.length - 1"
                  >▼</button>
                </div>
              </div>
            </div>
          </div>
          <div v-else class="empty-state">
            No Images
          </div>
        </div>
      </div>
      <div class="output">
        <textarea readonly v-model="generatedCSS"></textarea>
        <button class="copy-button" @click="copyToClipboard" title="Copy to clipboard">
          <span class="copy-icon">⧉ Copy</span>
        </button>
        <div class="output-controls">
          <div class="control-group">
            <label>img path:</label>
            <input 
              type="text" 
              v-model="imgPath"
              placeholder="./"
              class="path-input"
            >
          </div>
          <div class="control-group">
            <label>Color:</label>
            <input 
              type="color" 
              v-model="backgroundColor"
              class="color-input"
              value="#ffffff"
              alpha="alpha"
            >
            <input 
              type="text" 
              v-model="backgroundColor"
              placeholder="none"
              class="color-text-input"
            >
          </div>
          <div class="control-group">
            <label>
              <input 
                type="checkbox" 
                v-model="useShortcode"
              >
              shortcode
            </label>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style>
body {
  margin: 0;
  padding: 0;
  background: #e0e0e0;
  min-height: 100vh;
}

.app-container {
  padding: 10px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  height: 100vh;
  box-sizing: border-box;
  width: 100%;
  overflow: hidden;
  position: relative;
}

.app-container::before {
  content: '';
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: -1;
}

.top-panel {
  flex: 1 1 0;
  /* min-height: 200px; */
  position: relative;
}
h1 {
  color: white;
  font-size: min(5vw,35px);
  font-weight: 200;
  margin: 0;
  padding: 0;
  font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;
  font-weight: 600;
  position: absolute;
  bottom: calc(26px - 0.5em);
  left: 0;
  right: 0;
  text-align: center;
  z-index: 100;
  pointer-events: none;
}
.logo {
  position: absolute;
  bottom: 0px;
  right: 50px;
  z-index: 100;
}
.logo img {
  height: 40px;
  width: auto;
}
.canvas-container {
  background: #f0f0f0;
  position: relative;
  border-radius: 4px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  overflow: hidden;
  height: 100%;
  min-height: 400px;
}

.canvas {
  width: 100%;
  height: 100%;
  position: relative;
  border-radius: 4px;
  overflow: visible;
  container-type: size;
}

.canvas-inner {
  position: absolute;
  background: #fff;
  overflow: hidden;
}

.image-container {
  position: absolute !important;
  cursor: move;
  display: block !important;
  mix-blend-mode: var(--blend-mode, normal);
}
.main-image {
  position: absolute !important;
  inset: 0;
}
.image-container img {
  display: block !important;
  position: absolute !important;
  inset: 0;
  object-fit: fill;
}


.tile-container {
  position: absolute !important;
  inset: -10000%;
  overflow: hidden;
  pointer-events: none;
  z-index: 1;
}

.tile-overlay {
  position: absolute !important;
  inset: 0;
  background-position: center;
  transition: opacity 1s;
}
.canvas-container:hover .tile-overlay {
  opacity: 0.3;
}

.bounding-box {
  position: absolute !important;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  border: 2px solid transparent;
  pointer-events: none;
  z-index: 2;
}

.image-container.selected .bounding-box {
  border-color: #9e9e9e;
}

.coordinates {
  position: absolute !important;
  left: 8px;
  top: 8px;
  background: rgba(0,0,0,0.7);
  color: white;
  padding: 2px 4px;
  font-size: 12px;
  border-radius: 4px;
  white-space: nowrap;
  pointer-events: none;
  z-index: 3;
  line-height: 1.2;
}

.resize-handle {
  width: 10px;
  height: 10px;
  background: #2196f3;
  position: absolute !important;
  cursor: se-resize;
  pointer-events: auto !important;
  border-radius: 50%;
  z-index: 4;
  opacity: 0;
  visibility: hidden;
}

.image-container.selected .resize-handle {
  opacity: 1;
  visibility: visible;
}

.resize-handle.top-left {
  left: -5px;
  top: -5px;
  cursor: nw-resize;
}

.resize-handle.top-right {
  display: none;
}

.resize-handle.bottom-left {
  left: -5px;
  bottom: -5px;
  cursor: sw-resize;
}

.resize-handle.bottom-right {
  right: -5px;
  bottom: -5px;
  cursor: se-resize;
}

.bottom-panel {
  /* flex: 0 0 25em;
  min-height: 200px; */
  display: grid;
  grid-template-columns: minmax(300px, var(--left-panel-width, 1fr)) minmax(300px, 1fr);
  gap: 10px;
  height: 22em;
}

.image-controls, .output {
  min-width: 0;
  background: white;
  padding: 15px;
  border-radius: 4px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  height: 100%;
  display: flex;
  flex-direction: column;
}

.panel-title {
  display: none;
}

.plus-icon {
  font-size: 18px;
  font-weight: bold;
  margin-right: 4px;
}

.control-groups {
  flex: 1;
  overflow-y: auto;
  padding-right: 8px;
}

.control-group {
  display: grid;
  grid-template-columns: 60px 80px 1fr 80px 24px;
  gap: 8px;
  align-items: center;
  margin-bottom: 12px;
}

.control-group label {
  white-space: nowrap;
  color: #666;
  font-size: 14px;
}

.input-wrapper {
  position: relative;
  display: flex;
  align-items: center;
  gap: 4px;
}

.quick-buttons {
  display: flex;
  gap: 2px;
  margin-right: 4px;
}

.quick-buttons button {
  padding: 2px 4px;
  min-width: 24px;
  height: 20px;
  line-height: 1;
  background: #f5f5f5;
  border: 1px solid #ddd;
  border-radius: 4px;
  color: #666;
  font-size: 11px;
}

.quick-buttons button:disabled {
  opacity: 0.5;
}

.quick-buttons button:not(:disabled):hover {
  background: #e8e8e8;
  cursor: pointer;
}

.input-wrapper input[type="number"] {
  flex: 1;
  min-width: 0;
}

.control-group input[type="number"] {
  width: 100%;
  min-width: 4em;
  text-align: right;
  padding: 4px 8px;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 14px;
}

.control-group select {
  width: 100%;
  padding: 4px 8px;
  border: 1px solid #ddd;
  border-radius: 4px;
  background: white;
  font-size: 14px;
}

.control-group button.reset {
  padding: 4px;
  min-width: 24px;
  height: 24px;
  line-height: 1;
  background: #f5f5f5;
  border: 1px solid #ddd;
  border-radius: 4px;
  color: #666;
  cursor: pointer;
  display: none;
}

.control-group button.reset:hover {
  background: #e8e8e8;
}

.output {
  min-width: 0;
  background: white;
  padding: 15px;
  border-radius: 4px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  overflow: hidden;
  position: relative;
  display: flex;
  flex-direction: column;
}

.output textarea {
  flex: 1;
  width: 100%;
  margin: 0;
  padding: 10px;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-family: monospace;
  font-size: 14px;
  resize: none;
  box-sizing: border-box;
  background: white;
}

.output-controls {
  display: flex;
  flex-wrap: wrap;
  gap: 16px;
  padding-top: 12px;
  align-items: center;
}

.output-controls .control-group {
  display: flex;
  align-items: center;
  gap: 8px;
  margin: 0;
}

.output-controls label {
  white-space: nowrap;
  color: #666;
  font-size: 14px;
  display: flex;
  align-items: center;
  gap: 4px;
}
.control-group:has(.path-input) {
  flex: 1;
}
.path-input {
  flex: 1;
  width: 200px;
  padding: 4px 8px;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 14px;
}

.copy-button {
  position: absolute;
  top: 23px;
  right: 23px;
  padding: 6px;
  background: rgba(33, 150, 243, 0.1);
  color: #2196f3;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  opacity: 0;
  transition: opacity 0.2s, background-color 0.2s;
}

.output:hover .copy-button {
  opacity: 1;
}

.copy-button:hover {
  background: rgba(33, 150, 243, 0.2);
}

.copy-icon {
  font-size: 16px;
}

.layer-controls {
  display: flex;
  gap: 8px;
  margin-bottom: 20px;
}

.layer-controls button {
  flex: 1;
  padding: 4px 8px;
  font-size: 12px;
}

.checkbox-wrapper {
  display: flex;
  align-items: center;
  gap: 4px;
  user-select: none;
}

.checkbox-wrapper input[type="checkbox"] {
  margin: 0;
  width: 16px;
  height: 16px;
}

.checkbox-wrapper span {
  font-size: 14px;
  color: #666;
}

.layer-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 8px 0;
}

.layer-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px;
  border-radius: 4px;
  background: #f5f5f5;
  cursor: pointer;
  transition: background-color 0.2s;
  user-select: none;
}

.layer-item:hover {
  background: #e8e8e8;
}

.layer-item.selected {
  background: #e3f2fd;
}

.layer-item img.layer-thumbnail {
  width: 48px;
  height: 48px;
  object-fit: cover;
  border-radius: 4px;
  border: 1px solid #ddd;
}

.layer-name {
  font-size: 14px;
  color: #333;
  flex-grow: 1;
  text-align: left;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.layer-buttons {
  display: flex;
  gap: 4px;
}

.layer-button {
  padding: 2px 8px;
  font-size: 12px;
  background: transparent;
  border: 1px solid #ddd;
  border-radius: 4px;
  cursor: pointer;
  color: #666;
}

.layer-button:hover:not(:disabled) {
  background: #e0e0e0;
}

.layer-button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.empty-state {
  text-align: center;
  color: #666;
  padding: 20px;
  background: #f5f5f5;
  border-radius: 4px;
  margin: 10px 0;
}

h4 {
  margin: 0 0 10px 0;
  color: #333;
}
label {
  user-select: none;
}
.radio-group {
  display: flex;
  gap: 12px;
  align-items: center;
  padding: 4px 0;
  user-select: none;
}

.radio-group label {
  display: flex;
  align-items: center;
  gap: 4px;
  cursor: pointer;
  font-size: 14px;
  color: #666;
}

.radio-group input[type="radio"] {
  margin: 0;
  width: 16px;
  height: 16px;
}
.canvas-control-group {
  z-index: 110;
  position: absolute;
  bottom: 10px;
  left: 10px;
  display: flex;
  align-items: center;
  gap: 20px;
  opacity: 0;
  transition: opacity 0.6s;
}
.canvas-container:hover .canvas-control-group {
  opacity: 1;
}
.add-image-button {
  background: rgba(33, 150, 243, 0.9);
  color: white;
  backdrop-filter: blur(4px);
  padding: 8px 16px;
  border-radius: 4px;
  display: flex;
  align-items: center;
  gap: 4px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.2);
  transition: background-color 0.2s;
}

.add-image-button:hover {
  background: rgba(25, 118, 210, 0.9);
}

.canvas-control-group .checkbox-wrapper {
  display: flex;
  align-items: center;
  gap: 8px;
}


.delete-button {
  position: absolute !important;
  top: -8px;
  right: -8px;
  width: 16px;
  height: 16px;
  background: #ff4444;
  color: white;
  border: none;
  border-radius: 50%;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  line-height: 1;
  padding: 0;
  pointer-events: auto;
  z-index: 4;
  opacity: 0;
  visibility: hidden;
}

.image-container.selected .delete-button {
  opacity: 1;
  visibility: visible;
}

.delete-button:hover {
  background: #ff0000;
}

.aspect-ratio-lock {
  position: absolute !important;
  right: 8px;
  bottom: 8px;
  width: 20px;
  height: 20px;
  background: white;
  border: 1px solid #2196f3;
  border-radius: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  cursor: pointer;
  padding: 0;
  z-index: 4;
  pointer-events: auto !important;
  opacity: 0;
  visibility: hidden;
  transition: background-color 0.2s, color 0.2s;
}

.image-container.selected .aspect-ratio-lock {
  opacity: 1;
  visibility: visible;
}

.aspect-ratio-lock.locked {
  background: #2196f3;
  color: white;
}

.color-input {
  width: 40px;
  height: 24px;
  padding: 0;
  border: 1px solid #ddd;
  border-radius: 4px;
  cursor: pointer;
}

.color-text-input {
  width: 80px;
  padding: 4px 8px;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 14px;
  font-family: monospace;
}
</style>
