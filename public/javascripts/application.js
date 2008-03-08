// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

function quickRedReference() {
  window.open( 
    "/static/greencloth",
    "redRef",
    "height=600,width=750/inv,channelmode=0,dependent=0," +
    "directories=0,fullscreen=0,location=0,menubar=0," +
    "resizable=0,scrollbars=1,status=1,toolbar=0"
  );
}

function show_tab(tab_link, tab_content) {
  tabs = [document.getElementsByClassName("tab"),document.getElementsByClassName("tab-link")].flatten();
  for(i = 0; i < tabs.length; i++) {
    Element.removeClassName(tabs[i], 'selected');
  }
  tabs = document.getElementsByClassName("tab-content");
  for(i = 0; i < tabs.length; i++) {
    Element.hide(tabs[i]);
  }
  Element.addClassName(tab_link, 'selected');
  Element.addClassName(tab_link.ancestors().first(), 'selected');
  Element.show(tab_content);
  tab_link.blur();
  return false;
}

// submits a form, from the onclick of a link. 
// use like <a href='' onclick='submit_form(this,"bob")'>bob</a>
function submit_form(link, name, value) {
  form = link.ancestors().find(function(e) {
    return e.nodeName == 'FORM';
  })
  e = document.createElement("input");
  e.name = name;
  e.type = "hidden";
  e.value = value;
  form.appendChild(e);
  if (form.onsubmit) {
    form.onsubmit(); // for ajax forms.
  } else {
    form.submit();
  }
}

function toggleLink(link, text) {
  if ( link.innerHTML != text )  {
    link.oldInnerHTML = link.innerHTML;
    link.innerHTML = text;    
  } else {
    link.innerHTML = link.oldInnerHTML;
  }
  link.blur();
}

/* I can't get Element.toggle to work with $$().each, because it returns [element,number]
   for each element and not element. */
function mytoggle(element) {
    Element.toggle(element)
}

/* initialize links with class "remote" as remote links" */
$$("a.remote").invoke( "observe", 'click', function(event) {
  new Ajax.Request(this.href, {asynchronous:true, evalScripts:true, method:'get'});
  return false;
});


