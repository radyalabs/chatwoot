<script>
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import { useDarkMode } from 'widget/composables/useDarkMode';
import { getContrastingTextColor } from '@chatwoot/utils';

export default {
  components: {
    FluentIcon,
  },
  props: {
    url: {
      type: String,
      default: '',
    },
    attachment: {
      type: Object,
      default: () => ({}),
    },
    isInProgress: {
      type: Boolean,
      default: false,
    },
    widgetColor: {
      type: String,
      default: '',
    },
    isUserBubble: {
      type: Boolean,
      default: false,
    },
  },
  setup() {
    const { getThemeClass } = useDarkMode();
    return { getThemeClass };
  },
  // --- BAGIAN DEBUGGING (Agar Anda bisa cek Console) ---
  mounted() {
    if (this.isInProgress) {
      console.log('🔍 [FileBubble Mounted] Status: Uploading...');
      console.log('   - Attachment Data:', this.attachment);
      console.log('   - URL:', this.url);
    }
  },
  updated() {
    // Log hanya jika attachment berubah (untuk memantau perubahan dari in_progress -> sent)
    if (this.attachment && this.attachment.file_name) {
      // console.log('✅ [FileBubble Updated] Name:', this.attachment.file_name);
    }
  },
  // ----------------------------------------------------
  computed: {
    fileName() {
      // 1. Cek langsung dari prop attachment
      if (this.attachment && this.attachment.file_name) {
        return this.attachment.file_name;
      }

      // 2. Fallback ke URL jika nama kosong
      if (this.url) {
        try {
          let name = this.url.substring(this.url.lastIndexOf('/') + 1);
          name = decodeURIComponent(name.split('?')[0]);
          // Jika nama blob/uuid panjang, biarkan saja dulu agar terlihat ada isinya
          return name;
        } catch (e) {
          return 'Dokumen';
        }
      }
      return 'Dokumen';
    },
    
    fileExtension() {
      // Coba ambil dari data attachment dulu
      if (this.attachment.extension) return this.attachment.extension.toUpperCase();
      
      // Jika tidak ada, ambil dari akhiran nama file
      const name = this.fileName;
      if (name && name.includes('.')) {
         return name.split('.').pop().toUpperCase();
      }
      return 'FILE';
    },

    readableFileSize() {
      const size = this.attachment.file_size;
      if (!size) return '';
      const i = Math.floor(Math.log(size) / Math.log(1024));
      return (
        (size / Math.pow(1024, i)).toFixed(2) * 1 +
        ' ' +
        ['B', 'KB', 'MB', 'GB', 'TB'][i]
      );
    },

    fileIconColor() {
      const ext = this.fileExtension.toLowerCase();
      if (['pdf'].includes(ext)) return '#ef4444'; // Merah
      if (['xls', 'xlsx', 'csv'].includes(ext)) return '#10b981'; // Hijau
      if (['doc', 'docx'].includes(ext)) return '#3b82f6'; // Biru
      if (['zip', 'rar', '7z'].includes(ext)) return '#f59e0b'; // Oranye
      if (['ppt', 'pptx'].includes(ext)) return '#f97316'; // Jingga
      
      // Default: Ikuti warna teks
      return this.textColor || '#666'; 
    },

    contrastingTextColor() {
      return getContrastingTextColor(this.widgetColor);
    },

    textColor() {
      return this.isUserBubble && this.widgetColor
        ? this.contrastingTextColor
        : '';
    },
  },
};
</script>

<template>
  <a
    class="file-card"
    :href="isInProgress ? '#' : url"
    :target="isInProgress ? '' : '_blank'"
    rel="noreferrer noopener nofollow"
    :style="{ borderColor: isUserBubble ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.05)' }"
    :class="{ 'cursor-default': isInProgress }"
    @click="isInProgress ? $event.preventDefault() : null"
  >
    <div class="file-icon-wrapper" :style="{ color: fileIconColor }">
       <div class="icon-bg" :class="{'is-user': isUserBubble}">
          <FluentIcon icon="document" size="24" />
          <span class="ext-badge">{{ fileExtension }}</span>
       </div>
    </div>

    <div class="file-info">
      <div 
        class="file-name" 
        :style="{ color: textColor }"
        :title="fileName"
      >
        {{ fileName }}
      </div>
      
      <div class="file-meta" :style="{ color: textColor, opacity: 0.85 }">
         <span v-if="isInProgress">Mengunggah...</span>
         <span v-else>
            {{ readableFileSize }} <span v-if="readableFileSize">•</span> {{ fileExtension }}
         </span>
      </div>

      <div v-if="isInProgress" class="progress-track mt-1">
        <div class="progress-bar"></div>
      </div>
    </div>
  </a>
</template>

<style lang="scss" scoped>
@import 'widget/assets/scss/variables.scss';

.file-card {
  display: flex;
  align-items: center;
  padding: 10px 12px;
  text-decoration: none;
  border-radius: 8px;
  background-color: rgba(0, 0, 0, 0.04);
  min-width: 220px;
  max-width: 280px;
  border: 1px solid transparent;
  position: relative;
  overflow: hidden;
  transition: background-color 0.2s;

  &:hover {
    background-color: rgba(0, 0, 0, 0.08);
  }

  &.cursor-default {
    cursor: default;
    &:hover { background-color: rgba(0, 0, 0, 0.04); }
  }
}

.file-icon-wrapper {
  position: relative;
  margin-right: 12px;
  flex-shrink: 0;

  .icon-bg {
    width: 42px;
    height: 42px;
    background: white;
    border-radius: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
    position: relative;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
    
    &.is-user {
      background: rgba(255,255,255, 0.95);
    }
  }

  .ext-badge {
    position: absolute;
    bottom: -5px;
    right: -5px;
    background: #444;
    color: white;
    font-size: 8px;
    padding: 2px 4px;
    border-radius: 4px;
    font-weight: 700;
    text-transform: uppercase;
    box-shadow: 0 1px 2px rgba(0,0,0,0.2);
    max-width: 35px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
}

.file-info {
  display: flex;
  flex-direction: column;
  flex: 1;
  overflow: hidden;
  justify-content: center;
}

.file-name {
  font-weight: 600;
  font-size: 14px;
  line-height: 1.4;
  margin-bottom: 2px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  display: block;
}

.file-meta {
  font-size: 11px;
  font-weight: 400;
}

/* --- PROGRESS BAR STYLES --- */
.progress-track {
  width: 100%;
  height: 4px;
  background-color: rgba(0,0,0,0.1); /* Track abu-abu transparan */
  border-radius: 2px;
  overflow: hidden;
  position: relative;
  margin-top: 6px;
}

.progress-bar {
  width: 100%;
  height: 100%;
  background-color: #3b82f6; /* Warna Biru Loading */
  border-radius: 2px;
  /* Animasi loading yang bergerak terus menerus */
  animation: progress-indeterminate 1.5s infinite linear;
  transform-origin: 0% 50%;
}

@keyframes progress-indeterminate {
  0% {
    transform:  translateX(0) scaleX(0);
  }
  40% {
    transform:  translateX(0) scaleX(0.4);
  }
  100% {
    transform:  translateX(100%) scaleX(0.5);
  }
}
</style>