$(function () {
  $("form.delete").submit(function (event) {
    event.preventDefault()
    event.stopPropagation()

    var ok = confirm("Are you sure? This cannot be undone!");
    if (ok) {
      // this.submit();
      
      var form = $(this);

      // AJAX Request
      var request = $.ajax({
        url: form.attr("action"),
        method: form.attr("method")
      });

      // Upon successful request (not 4xx or 5xx)
      request.done(function(data, textStatus, jqXHR) {
      if (jqXHR.status === 204) {
        // Delete a todo
        form.parent("li").remove()
      } else if (jqXHR.status === 200) {
        // Redirect
        document.location = data;
      }
    });
    }
  });
});
