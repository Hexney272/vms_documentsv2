const safeHtml = (typeof escapeHtml === 'function') ? escapeHtml : function(value) {
    return String(value ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
};

const LoadLicenses = function(licenses) {
    let licensesData = '';

    for (const [k, v] of Object.entries(licenses)) {
        licensesData += `
            <div>
                <div class="label">${safeHtml(v.label)}</div>
                ${v.price && v.price >= 1 && `<div class="order" onclick="orderDocument('${v.name}')">${translation.documents_menu.documents_list.order_for_btn} ${translation.currency}${v.price}</div>` || `<div class="order" onclick="orderDocument('${v.name}')">${translation.documents_menu.documents_list.order_btn}</div>`}
            </div>
        `
    }

    return licensesData;
}

const LoadOwnedDocumentPhotos = function(photosList) {
    let photosData = '';
    if (photosList) {
        for (const [k, v] of Object.entries(photosList)) {
            if (!v.used) {
                let photoId = Number(k) + 1
                photosData += `
                    <div>
                        <img src="${safeHtml(v.img)}">
                        <div>
                            <div>${translation.documents_menu.photos_list.id}: ${safeHtml(photoId)}</div>
                            <div id="remove-photo" onclick="removePhoto(${safeHtml(photoId)})">${translation.documents_menu.photos_list.remove_photo_btn}</div>
                            <div id="select-photo" onclick="selectDocumentPhoto(${safeHtml(photoId)})">${translation.documents_menu.photos_list.select_photo_btn}</div>
                        </div>
                    </div>
                `
            }
        }
        $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="photos"] > .photos-list > div').html(photosData);
    }
}

const LoadOwnedDocuments = function(ownedDocumentsList) {
    let documentsData = '';
    if (ownedDocumentsList) {
        for (const [k, v] of Object.entries(ownedDocumentsList)) {
            documentsData += `
                <div>
                    <div>
                        <i class="fa-solid fa-id-card"></i>
                    </div>
                    <div class="info">
                    
                        <span>${translation.documents_menu.owned_documents_list.document_type}: <span>${safeHtml(licensesNames[v.type] || v.type)}</span></span>
                        <span id="serial-number">${translation.documents_menu.owned_documents_list.serial_number}: <span data-value="${safeHtml(v.serial_number)}">${safeHtml(v.serial_number)}</span></span>
                        <div class="invalidate" onclick="invalidateDocument('${safeHtml(v.serial_number)}')">${translation.documents_menu.owned_documents_list.report_btn}</div>
                    </div>
                </div>
            `
        }
    }
    $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="owned-documents"] > .documents-list > div').html(documentsData);
}