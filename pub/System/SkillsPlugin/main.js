SkillsPlugin.vars.mapping = {
    ' ': '20', '!': '21', '"': '22', '#': '23', '$': '24', 
    '%': '25', '&': '26', '´': '27', '(': '28', ')': '29', 
    '*': '2a', '+': '2b', ',': '2c', '/': '2f', ':': '3a', 
    ',': '3b', '<': '3c', '=': '3d', '>': '3e', '?': '3f', 
    '@': '40', '[': '5b', "'": '5c', ']': '5d', '^': '5e', 
    '`': '60', '{': '7b', '|': '7c', '}': '7d', '~': '7e'
};

SkillsPlugin.main = {
    
    // enable/disable inputs for the given class
    enableByClassName: function(className, enable){
        var yuiEl = new YAHOO.util.Element();
        var els = yuiEl.getElementsByClassName(className);
        for (var i in els) {
            els[i].disabled = !enable;
        }
    },

    enableById: function(id, enable){
        var el = document.getElementById(document, id);
        if (el != null)
            el.disabled = !enable;
    },

    // common function for all connection failures
    _connectionFailure: function(o){
        alert("Connection failure '" + o.statusText + "'. Please notify your administrator, giving the reason for this failure and as much information about the problem as possible.");
    },
    
    get: function(handler, fnCallback, x1, x2, x3) {
        var url = SkillsPlugin.vars.restUrl + "/SkillsPlugin/" + handler;
        
        var obCallbacks = {
            success: function(o){                
                var reply = YAHOO.lang.JSON.parse(o.responseText);
                fnCallback( reply, x1, x2, x3 );
            },
            failure: function(o){
                SkillsPlugin.main._connectionFailure(o);
            }
        }
        var request = YAHOO.util.Connect.asyncRequest(
            'GET', url, obCallbacks); 
    },
    
    submit: function(rest, formid, messid, fnCallback) {
        var url = SkillsPlugin.vars.restUrl + '/SkillsPlugin/' + rest;
        var obForm = document.getElementById(formid);
        YAHOO.util.Connect.setForm(obForm);
        var obCallbacks = {
            success: function(o){
                SkillsPlugin.main.unlockForm();
                if (fnCallback)
                    fnCallback(o);
                // If there's an id for a message field given, use it
                // to display the response text
                if (messid)
                    SkillsPlugin.main.displayMessage(
                        o.responseText, messid);
            },
            failure: function(o){
                SkillsPlugin.main.unlockForm();
                SkillsPlugin.main._connectionFailure(o);
            }
        }

        SkillsPlugin.main.lockForm();
        YAHOO.util.Connect.asyncRequest('POST', url, obCallbacks);
    },

    //////////// MESSAGES

    // displays a notification recieved from the server
    displayMessage: function(message, id){
        
        var elMessage = document.getElementById(id);
        elMessage.innerHTML = message;
        
        this.showMessage( id );
    },
    
    // shows the message
    showMessage: function(id){
        var elMessageContainer = document.getElementById(
            id + '-container');
        elMessageContainer.style.display = '';
        // message is shown for 10 seconds
        var obAnim = new YAHOO.util.Anim(
            elMessageContainer,
            {
              opacity: {to: 0, from:1}
            }, 
            10
            );
        obAnim.animate();
    },

    /////////////// TOOLTIPS

    // Add the relevant cat/skill as a tooltip on an element
    tipify: function(el) {
        var yel = new YAHOO.util.Element(el);
        yel.addClass('skillsTipped');
    },

    // Attach tooltips to all elements of class skillsTipped. On the
    // face of it, this is inefficient because it creates a new
    // tooltip for every link. But that's OK, because we know that
    // 99% of the time, there will only be one use of a tooltip
    // in any given page.
    createTooltips: function() {
        var el = document.getElementsByTagName('BODY');
        var yuiEl = new YAHOO.util.Element(el[0]);
        yuiEl.addClass('yui-skin-sam');
        var els = document.getElementsByClassName('skillsTipped');
        var map = {};
        for (var i = 0; i < els.length; i++) {
            // Get the tooltip div id from the title
            var ttid = "tip" + els[i].id;
            var div = document.getElementById(ttid);
            if (div == null) {
                continue;
            }
            var text = div.innerHTML;
            map[els[i].id] = text;
        }
        for (var id in map) {
            var ttel = new YAHOO.widget.Tooltip(
                ttid + "Tooltip",
                { context: id, text: map[id] } );
            var yel = new YAHOO.util.Element(id);
            yel.removeClass('skillsTipped');
        }
    },

    //////// TWISTIES

    initTwisties: function(){
        // sets up the twisty
        var yuiEl = new YAHOO.util.Element();
        
        if ( SkillsPlugin.vars.twistyState == 'off' ){
            return;
        }
        
        var arEls = yuiEl.getElementsByClassName(
            'SkillsPlugin-twisty-link', 'span');
        
        var fnTwistCallback = function(){
            SkillsPlugin.main.twist( this );
        };
        
        // add event to an array of elements
        YAHOO.util.Event.addListener(
            arEls,
            "click",
            fnTwistCallback
            );
        
        // loop over all twisty links
        for ( var i = arEls.length - 1; i >= 0; --i ){
            var twistyId = arEls[i].id.replace( /_.*$/, '');
            
            var elLink = new YAHOO.util.Element(
                twistyId + '_twistyLink' );
            elLink.addClass('active');
            var elImg = new YAHOO.util.Element(
                twistyId + '_twistyImage' );
            elImg.addClass('active');
            
            // set initial state
            if( SkillsPlugin.vars.twistyState == 'closed' ){
                SkillsPlugin.main.twist( arEls[i] );
            }
        }
    },

    twist: function( elTwistyLink ) {
        var yuiEl = new YAHOO.util.Element();
        
        var twistyId = elTwistyLink.id.replace( /_.*$/, '');
        
        var elsToTwist = yuiEl.getElementsByClassName(
            twistyId + '_twist' );
        
        var elTwistyImgCont  = document.getElementById(
            twistyId + '_twistyImage' );
        var elTwistyImg;
        if( elTwistyImgCont ){
            elTwistyImg = document.getElementById(
                twistyId + '_twistyImage' ).childNodes[1];
        }
        
        // are we open or close?
        var elTwistyLink = new YAHOO.util.Element(elTwistyLink);
        if( elTwistyLink.hasClass( 'twistyopen' ) ){
            elTwistyLink.replaceClass( 'twistyopen', 'twistyclosed' );
            for( var i in elsToTwist ){
                this.closeTwist( elsToTwist[i], elTwistyImg );
            }
        }
        else if( elTwistyLink.hasClass( 'twistyclosed' ) ){
            elTwistyLink.replaceClass( 'twistyclosed', 'twistyopen' );
            var i;
            for( i in elsToTwist ){
                this.openTwist( elsToTwist[i], elTwistyImg );
            }
        } else {
            elTwistyLink.addClass( 'twistyclosed' );
            var i;
            for( i in elsToTwist ){
                this.closeTwist( elsToTwist[i], elTwistyImg );
            }
        }
    },
    
    openTwist: function( twistEl, imageEl ) {
        try {
            twistEl.style.display = '';
        } catch(e) {
            twistEl.style.display = 'block';
        }
        if( imageEl ){
            imageEl.src = SkillsPlugin.vars.twistyCloseImgSrc;
        }
    },
    
    closeTwist: function( twistEl, imageEl ) {
        twistEl.style.display = 'none';
        if( imageEl ){
            imageEl.src = SkillsPlugin.vars.twistyOpenImgSrc;
        }
    },

    ////////// MULTI_USE APPLICATION SPECIFICS

    // lock form when AJAX in progress
    lockForm: function(){
        SkillsPlugin.main.enableByClassName('skillsControl', false);
    },
    
    // unlocks the form
    unlockForm: function(){
        SkillsPlugin.main.enableByClassName('skillsControl', true);
    },

    resetSelect: function(elSelect, message) {
        elSelect.options.length = 0;
        elSelect.options[0] = new Option(
            message, "0", true);
        elSelect.selectedIndex = 0;
    },

    populateSelect: function(screen, type, url) {
        var elSelect = document.getElementById(
            screen + "-" + type + "-select");

        if( SkillsPlugin.vars.loggedIn == 0 ) {
            this.resetSelect(elSelect, "Please log in...");
            return;
        }
        this.resetSelect(elSelect, "Loading...");
        
        var fnCallback = function( arResults ) {
            SkillsPlugin.main.resetSelect(
                elSelect, "Select a " + type + "...");
            var count = 1;
            for( var i in arResults.sort() ){
                elSelect.options[count++] = new Option(
                    arResults[i], arResults[i]);
            }
            SkillsPlugin.main.unlockForm();
        }

        SkillsPlugin.main.lockForm();
        SkillsPlugin.main.get(url, fnCallback);
    },

    // populates the category select menu
    populateCategorySelect: function(screen){

        var elSelect = document.getElementById(
            screen + "-skill-select");
        this.resetSelect(elSelect, "Select a category...");

        elSelect = document.getElementById(
            screen + "-subcategory-select");
        if (elSelect) {
            this.resetSelect(elSelect, "Select a category...");
        }

        this.populateSelect(screen, "category", 'getChildNodes');
    },

    // populates the subcategory select menu, if there is one
    populateSubCategorySelect: function(screen){
        var elSelect = document.getElementById(
            screen + "-skill-select");
        this.resetSelect(elSelect, "Select a category...");

        elSelect = document.getElementById(
            screen + "-category-select");
        var cat = elSelect.options[elSelect.selectedIndex].value;

        if( !cat ) {
            elSelect = document.getElementById(
                screen + "-subcategory-select");
            this.resetSelect(elSelect, "Select a category...");
            return;
        }
        this.populateSelect(
            screen, "subcategory",
            'getChildNodes?path1=' + encodeURIComponent(cat));
    },

    // populates the skill select menu
    populateSkillSelect: function(screen) {
        var elSelect = document.getElementById(
            screen + "-category-select");
        var cat = elSelect.options[elSelect.selectedIndex].value;

        var subcat = -1;
        elSelect = document.getElementById(screen + "-subcategory-select");
        if (elSelect) {
            subcat =
                elSelect.options[elSelect.selectedIndex].value;
        }

        elSelect = document.getElementById(
            screen + "-skill-select");
        this.resetSelect(elSelect, "Select a category...");

        if( cat == 0 || subcat == 0){
            return;
        }
        this.populateSelect(
            screen, "skill",
            "getChildNodes?path1=" + encodeURIComponent(cat)
            + ((subcat < 0) ? ''
               : ';path2='+ encodeURIComponent(subcat)));
    },

    createLineImg: function(name, el) {
        var img = document.createElement('img');
        img.src = SkillsPlugin.vars.lineSrc[name];
        img.alt = name;
        return img;
    },

    makeID: function(name) {
        var newname = name.replace(
            /[^0-9a-zA-Z-_.]/g,
            function(c) {
                var ch = SkillsPlugin.vars.mapping[c.charAt(0)];
                return ":" + ch;
            });
        //console.debug("'"+name+"' -> '"+newname+"'");
        return newname;
    }
};

YAHOO.util.Event.onDOMReady(
    function() {
        SkillsPlugin.main.initTwisties();
        SkillsPlugin.main.createTooltips();
    });
