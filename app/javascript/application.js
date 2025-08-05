import "@hotwired/turbo-rails"
import "controllers"

document.addEventListener("turbo:load", function() {
    var contentTextArea = document.getElementById('recipe_content');
    if (contentTextArea) {
        CodeMirror.fromTextArea(contentTextArea, {
            lineWrapping: true,
        });
    }

    const flashMessages = document.querySelectorAll('.flash');

    flashMessages.forEach(message => {
        const closeButton = message.querySelector('a');
        let autoHideTimeout;

        const hideMessage = () => {
            message.style.display = 'none';
        };

        autoHideTimeout = setTimeout(hideMessage, 5000);

        if (closeButton) {
            closeButton.addEventListener('click', (event) => {
                event.preventDefault();
                clearTimeout(autoHideTimeout);
                hideMessage();
            });
        }
    });
});