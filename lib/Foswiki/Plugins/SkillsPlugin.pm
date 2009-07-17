# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2007 - 2009 Andrew Jones, andrewjones86@googlemail.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the Foswiki root.

package Foswiki::Plugins::SkillsPlugin;

# Conditionally required in this module
#require Foswiki::Plugins::SkillsPlugin::Category;
#require Foswiki::Plugins::SkillsPlugin::UserSkill;
#require Foswiki::Plugins::SkillsPlugin::UserSkills;
#require Foswiki::Plugins::SkillsPlugin::SkillsStore;

use strict;

use JSON ();

use vars qw(
  $pluginName
  $doneHeads
);

# Plugin Variables
our $VERSION           = '$Rev$';
our $RELEASE           = '16 Jul 2009';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION =
  'Allows users to list their skills, which can then be searched';

$pluginName = 'SkillsPlugin';

# ========================= INIT
sub initPlugin {

    # Register tag %SKILLS%
    Foswiki::Func::registerTagHandler( 'SKILLS', \&_handleTag );
    # Register tag %SKILLRATINGS%
    Foswiki::Func::registerTagHandler( 'SKILLRATINGS', \&_SKILLRATINGS );

    # Register REST handlers
    Foswiki::Func::registerRESTHandler(
        'addNewCategory', \&_restAddNewCategory );
    Foswiki::Func::registerRESTHandler(
        'renameCategory', \&_restRenameCategory );
    Foswiki::Func::registerRESTHandler(
        'deleteCategory', \&_restDeleteCategory );
    Foswiki::Func::registerRESTHandler(
        'addNewSkill',    \&_restAddNewSkill );
    Foswiki::Func::registerRESTHandler(
        'renameSkill',    \&_restRenameSkill );
    Foswiki::Func::registerRESTHandler(
        'moveSkill',      \&_restMoveSkill );
    Foswiki::Func::registerRESTHandler(
        'deleteSkill',    \&_restDeleteSkill );
    Foswiki::Func::registerRESTHandler(
        'search', \&_restSearch );
    Foswiki::Func::registerRESTHandler(
        'getCategories', \&_restGetCategories );
    Foswiki::Func::registerRESTHandler(
        'getSkills',     \&_restGetSkills );
    Foswiki::Func::registerRESTHandler(
        'getSkillDetails', \&_restGetSkillDetails );
    Foswiki::Func::registerRESTHandler(
        'addEditSkill', \&_restAddEditSkill );

    Foswiki::Func::registerRESTHandler(
        'getSkillsAndDetails', \&_restGetSkillsAndDetails );
    Foswiki::Func::registerRESTHandler(
        'saveUserChanges', \&_restSaveUserChanges );

    _Debug("initPlugin is OK");

    return 1;
}

# ========================= TAGS
sub _handleTag {

    my $out = '';

    my $action =
         $_[1]->{action}
      || $_[1]->{_DEFAULT}
      || return 'No action specified';

    my $start = "<noautolink>\n";
    my $end   = "\n</noautolink>";

    $doneHeads = 0;

    for ($action) {
        /user/
          and $out =
          $start . Foswiki::Plugins::SkillsPlugin::_tagUserSkills( $_[1] ) . $end,
          last;

#    /group/ and $out = $start . Foswiki::Plugins::SkillsPlugin::Tag::_tagGroupSkills($_[1]) . $end, last; # shows skills for a particular group
        /browse/
          and $out =
            $start
          . Foswiki::Plugins::SkillsPlugin::_tagBrowseSkills( $_[1] )
          . $end, last;
        /editall/
          and $out =
          $start . Foswiki::Plugins::SkillsPlugin::_tagEditAllSkills( $_[1] ) . $end,
          last;
        /edit/
          and $out =
          $start . Foswiki::Plugins::SkillsPlugin::_tagEditSkills( $_[1] ) . $end,
          last;
        /showskill/
          and $out =
          $start . Foswiki::Plugins::SkillsPlugin::_tagShowSkills( $_[1] ) . $end,
          last;
        /showcat/
          and $out =
            $start
          . Foswiki::Plugins::SkillsPlugin::_tagShowCategories( $_[1] )
          . $end, last;    # show all categories in a format
        /^search$/
          and $out =
          $start . Foswiki::Plugins::SkillsPlugin::_tagSearchForm( $_[1] ) . $end,
          last;            # creates a search form
        /searchresults/
          and $out = $start . '<div id="search-skill-results"></div>' . $end,
          last;            # container for the results

        # action not valid
        $out =
          "<span class='foswikiAlert'>Error: Unknown action ('$action')</span>",
          last;
    }

    #$allowedit = 0;

    return $out;
}

sub _respaceName {
    my ($name, $br) = @_;
    $name =~ s/ /$br/g;
    return $name;
}

sub _SKILLRATINGS {
    my ($session, $params) = @_;

    my $skillNames =
      Foswiki::Func::getPreferencesValue("SKILLSPLUGIN_RATINGS")
          || "None,Ancient Knowledge,Working Knowledge,Expert,Guru";
    my @skills = split(/,\s*/, $skillNames);

    my $format =
      defined $params->{format} ? $params->{format} : '$name: $value';
    my $marker =
      defined $params->{marker} ? $params->{marker} : 'selected';
    my $separator =
      defined $params->{separator} ? $params->{separator} : '$n()';
    my $selection =
      defined $params->{selection} ? $params->{selection} : -1;
    $selection = $#skills if $selection eq '$';

    my @values = ();
    foreach my $value (0..$#skills) {
        my $name = $skills[$value];
        my $mark = ($value == $selection) ? $marker : '';
        my $item = $format;
        $item =~ s/\$name\((.*?)\)/_respaceName($name, $1)/ge;
        $item =~ s/\$name/$name/g;
        $item =~ s/\$value/$value/g;
        $item =~ s/\$marker/$mark/g;
        push(@values, $item);
    }
    my $out = join($separator, @values);
    return Foswiki::Func::decodeFormatTokens($out);
}

# allows the user to print all categories in format of their choice
sub _tagShowCategories {
    my $params = shift;

    return _showCategories( $params->{format}, $params->{separator} );
}

sub _tagShowSkills {
    my $params = shift;

    return _showSkills(
        $params->{category}, $params->{format}, $params->{separator},
        $params->{prefix},   $params->{suffix}
    );
}

# creates a form allowing users to edit their skills
sub _tagEditSkills {
    my $params = shift;
    my $user = Foswiki::Func::getWikiName();
    my $style = $params->{style} || '';

    my $out = Foswiki::Func::readTemplate('skillsedit'.$style);

    # expand our variables in template
    my $messagePic = _getImages()->{info};
    $out =~ s/%SKILLMESSAGEPIC%/$messagePic/g;

    # to clear textbox
    my $clearPic = _getImages()->{clear};
    $out =~ s/%SKILLCOMMENTCLEARPIC%/$clearPic/g;

    my $jsVars = <<JS;
SkillsPlugin.vars.addEditSkills = 1;
SkillsPlugin.vars.restUrl = "%SCRIPTURL{"rest"}%";
JS
    _addHeads($jsVars);

    return $out;
}

# creates a form allowing users to edit their skills
sub _tagEditAllSkills {
    my $params = shift;
    my $user = Foswiki::Func::getWikiName();

    my $out = Foswiki::Func::readTemplate('skillseditall');

    # expand our variables in template
    my $messagePic = _getImages()->{info};
    $out =~ s/%SKILLMESSAGEPIC%/$messagePic/g;

    my $jsVars = <<JS;
SkillsPlugin.vars.editAllSkills = 1;
SkillsPlugin.vars.restUrl = "%SCRIPTURL{"rest"}%";
JS
    _addHeads($jsVars);

    return $out;
}

sub _tagUserSkills {

    my $params = shift;

    my $user   = $params->{user}   || Foswiki::Func::getWikiName();
    my $twisty = $params->{twisty} || 'closed';

    my $out = Foswiki::Func::readTemplate('skillsuserview');

    my $tmplCat = Foswiki::Func::expandTemplate(
        "skills:userview:repeated:category");
    my $tmplCatContStart = Foswiki::Func::expandTemplate(
        "skills:userview:repeated:categorycontainerstart");
    my $tmplSkillStart = Foswiki::Func::expandTemplate(
        "skills:userview:repeated:skillstart");
    my $tmplSkill = Foswiki::Func::expandTemplate(
        "skills:userview:repeated:skill");
    my $tmplRating = Foswiki::Func::expandTemplate(
        "skills:userview:repeated:rating");
    my $tmplComment = Foswiki::Func::expandTemplate(
        "skills:userview:repeated:comment");
    my $tmplSkillEnd = Foswiki::Func::expandTemplate(
        "skills:userview:repeated:skillend");
    my $tmplCatContEnd = Foswiki::Func::expandTemplate(
        "skills:userview:repeated:categorycontainerend");

    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    require Foswiki::Plugins::SkillsPlugin::UserSkills;
    my $skills = Foswiki::Plugins::SkillsPlugin::SkillsStore->new()
      ;    # FIXME: dont need to go here!
    my $userSkills = Foswiki::Plugins::SkillsPlugin::UserSkills->new();

    # get image paths
    my $ratingPic      = _getImages()->{star};
    my $skillPic       = _getImages()->{open};
    my $commentPic     = _getImages()->{comment};
    my $twistyCloseImg = _getImages()->{twistyclose};

    my $jsVars =
      "if( !SkillsPlugin ) var SkillsPlugin = {}; SkillsPlugin.vars = {}; "
      ;    # create namespace in JS

    my $repeatedLine;

    my $itCategories = $skills->eachCat;
    while ( $itCategories->hasNext() ) {
        my $cat = $itCategories->next();

        my $catDone  = 0;
        my $skillOut = 0;

        # iterator over skills
        my $itSkills = $cat->eachSkill;
        while ( $itSkills->hasNext() ) {
            my $skill = $itSkills->next();

            # does user have this skill?
            if ( my $obj_userSkill =
                $userSkills->getSkillForUser( $user, $skill->name, $cat->name )
              )
            {

                # produce output line
                # add to array/string which will be output in %REPEAT%
                my $lineOut;

                $skillOut = 1;

                # category
                unless ( $catDone == 1 ) {
                    $lineOut .= $tmplCat;
                    $lineOut .= $tmplCatContStart;
                }
                $catDone = 1;

                $lineOut .= $tmplSkillStart;

                # skill
                $lineOut .= $tmplSkill;

                # rating
                my $i = 0;
                while ( $i < $obj_userSkill->rating ) {
                    my $ratingOut = $tmplRating;
                    $ratingOut =~ s/%RATING%/&nbsp;/g;
                    $ratingOut =~ s/%RATINGDEF%//g;
                    $lineOut .= $ratingOut;
                    $i++;
                }
                my $ratingOut = $tmplRating;
                $ratingOut =~ s/%RATING%/$ratingPic/g;
                $ratingOut =~ s/%RATINGDEF%/class='skillsRating'/g;
                $lineOut .= $ratingOut;
                $i++;
                while ( $i <= 4 ) {
                    my $ratingOut = $tmplRating;
                    $ratingOut =~ s/%RATING%/&nbsp;/g;
                    $ratingOut =~ s/%RATINGDEF%//g;
                    $lineOut .= $ratingOut;
                    $i++;
                }

                # comment
                $lineOut .= $tmplComment;

                $lineOut .= $tmplSkillEnd;

                # subsitutions
                my $skillName = $skill->name;
                $lineOut =~ s/%SKILL%/$skillName/g;
                $lineOut =~ s/%SKILLICON%/$skillPic/g;
                if ( $obj_userSkill->comment ) {
                    my $url = Foswiki::Func::getScriptUrl(
                        'Main', 'WebHome', 'oops',
                        template => 'oopsgeneric',
                        param1   => 'Skills Plugin Comment',
                        param2   => "Comment for skill '"
                          . $skill->name
                          . "' by $user",
                        param3 =>
"$user has logged the following comment next to skill '"
                          . $skill->name . "'.",
                        param4 => $obj_userSkill->comment
                    );
                    $url .= ';cover=skills';
                    my $commentLink =
                        "<a id='comment|"
                      . $cat->name . "|"
                      . $skill->name
                      . "' class='SkillsPluginComments' href=\"$url\" target='_blank' >$commentPic</a>";
                    $lineOut =~ s/%COMMENTLINK%/$commentLink/g;
                }
                else {
                    $lineOut =~ s/%COMMENTLINK%//g;
                    $lineOut =~ s/%COMMENTOUT%//g;
                }

                $repeatedLine .= $lineOut;
            }
        }

        # subsitutions
        my $catTwist =
            '<span id="'
          . _urlEncode( $cat->name )
          . '_twistyImage" class="SkillsPlugin-twisty-image"> '
          . $twistyCloseImg
          . '</span>';
        $repeatedLine =~ s!%SKILLTWISTY%!$catTwist!g;
        my $catLink =
            '<span id="'
          . _urlEncode( $cat->name )
          . '_twistyLink" class="SkillsPlugin-twisty-link">'
          . $cat->name
          . '</span>';
        $repeatedLine =~ s/%CATEGORY%/$catLink/g;
        my $skillContDef = 'class="' . _urlEncode( $cat->name ) . '_twist"';
        $repeatedLine =~ s/%SKILLCONTDEF%/$skillContDef/g;

        $repeatedLine .= $tmplCatContEnd unless ( $skillOut == 0 );
    }

    $out =~ s/%REPEAT%/$repeatedLine/g;
    $out =~ s/%SKILLUSER%/$user/g;

    my $twistyOpenImgSrc = _getImagesSrc()->{twistyopen};
    my $twistyCloseImgSrc = _getImagesSrc()->{twistyclose};

    $jsVars .= "SkillsPlugin.vars.twistyState = '$twisty';";
    $jsVars .= "SkillsPlugin.vars.twistyOpenImgSrc = \"$twistyOpenImgSrc\";";
    $jsVars .= "SkillsPlugin.vars.twistyCloseImgSrc = \"$twistyCloseImgSrc\";";
    $jsVars .= 'SkillsPlugin.vars.viewUserSkills = 1;';
    _addHeads($jsVars);

    return $out;
}

sub _tagSearchForm {
    my $out = Foswiki::Func::readTemplate('skillssearchform');

    # expand our variables in template
    my $messagePic = _getImages()->{info};
    $out =~ s/%SKILLMESSAGEPIC%/$messagePic/g;

    _addHeads(<<JS);
SkillsPlugin.vars.searchSkills = 1;
SkillsPlugin.vars.restUrl = "%SCRIPTURL{"rest"}%";
JS

    return $out;
}

sub _tagBrowseSkills {

    my $params = shift;

    my $twisty = $params->{twisty} || 'closed';

    my $out    = Foswiki::Func::readTemplate('skillsbrowseview');

    my $tmplCat = Foswiki::Func::expandTemplate(
        "skills:browseview:repeated:category");
    my $tmplCatContStart = Foswiki::Func::expandTemplate(
        "skills:browseview:repeated:categorycontainerstart");
    my $tmplSkillStart = Foswiki::Func::expandTemplate(
        "skills:browseview:repeated:skillstart");
    my $tmplSkill = Foswiki::Func::expandTemplate(
        "skills:browseview:repeated:skill");
    my $tmplUserStart = Foswiki::Func::expandTemplate(
        "skills:browseview:repeated:userstart");
    my $tmplUser = Foswiki::Func::expandTemplate(
        "skills:browseview:repeated:user");
    my $tmplUserEnd = Foswiki::Func::expandTemplate(
        "skills:browseview:repeated:userend");
    my $tmplRating = Foswiki::Func::expandTemplate(
        "skills:browseview:repeated:rating");
    my $tmplComment = Foswiki::Func::expandTemplate(
        "skills:browseview:repeated:comment");
    my $tmplSkillEnd = Foswiki::Func::expandTemplate(
        "skills:browseview:repeated:skillend");
    my $tmplCatContEnd = Foswiki::Func::expandTemplate(
        "skills:browseview:repeated:categorycontainerend");

    # loop over all skills from skills.txt
    # if a user has this skill, output them

    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    require Foswiki::Plugins::SkillsPlugin::UserSkills;
    my $skills = Foswiki::Plugins::SkillsPlugin::SkillsStore->new()
      ;    # FIXME: dont need to go here!
    my $userSkills = Foswiki::Plugins::SkillsPlugin::UserSkills->new();

    # get image paths
    my $ratingPic      = _getImages()->{star};
    my $open           = _getImages()->{open};
    my $commentPic     = _getImages()->{comment};
    my $twistyCloseImg = _getImages()->{twistyclose};

    my $repeatedLine = '';

    # loop over all users that have skills
    # if they do, store in hash/array ## CANT cos C++, etc
    # loop over array and do the output

# my $allUserSkills = $userSkills->allUsers();
#
# my $outSkills;
#
# # each user with skills
# for my $user( sort keys %{ $allUserSkills } ){
#
# # loop over all this users skills
# for my $user_obj( @{ $allUserSkills->{ $user } } ){
#
# next unless( $skills->categoryExists( $user_obj->category ) );
# next unless( $skills->getCategoryByName( $user_obj->category )->skillExists( $user_obj->name ) );
#
# # category
# $outSkills->{ $user_obj->category } = {} unless $outSkills->{ $user_obj->category };
# # skill
# $outSkills->{ $user_obj->category }->{ $user_obj->name } unless $outSkills->{ $user_obj->category }->{ $user_obj->name };
#
# #%outSkills->{ $user_obj->category }->{ $user_obj->name }->{ $user } = $user_obj;
#
# # check the category and skill is defined
# # add to hash
# }
#
# return $user;
# }
#
# return "hi" . $allUserSkills->{'AndrewJones'}[0]->name;
#return "hi";

    my $allUsers = $userSkills->allUsers();

    my $itCategories = $skills->eachCat;
    while ( $itCategories->hasNext() ) {
        my $cat = $itCategories->next();

        my $catName = $cat->name;

        $repeatedLine .= $tmplCat;

        $repeatedLine .= $tmplCatContStart;
        my $contId = _urlEncode($catName) . '_twist';
        $repeatedLine =~ s/%CATEGORYCONTCLASS%/$contId/g;

        # iterator over skills
        my $itSkills = $cat->eachSkill;
        while ( $itSkills->hasNext() ) {
            my $skill = $itSkills->next();

            my $skillName = $skill->name;

            $repeatedLine .= $tmplSkillStart;
            $repeatedLine .= $tmplSkill;
            $repeatedLine .= $tmplSkillEnd;

# now need to iterate over users and find out if they have this skill
# if so, output
# users should only be loaded the first time, the rest is in memory
# if this was an iterator of each user with skills
#my $users = Foswiki::Plugins::SkillsPlugin::UserSkills->new()->getUsersForSkill( $skillName, $catName );

            #for my $user ( sort keys %{ $users } ) {
            #my $obj_userSkill = $allUsers->{ $user };
            for my $user ( sort keys %{$allUsers} ) {
                for my $obj_userSkill ( @{ $allUsers->{$user} } ) {

                    next
                      unless ( $obj_userSkill->category eq $catName
                        and $obj_userSkill->name eq $skillName );

                    $repeatedLine .= $tmplUserStart;
                    $repeatedLine .= $tmplUser;

                    my $skillTwist =
                        'class="'
                      . _urlEncode($catName)
                      . _urlEncode($skillName)
                      . '_twist"';
                    $repeatedLine =~ s/%SKILLTWISTDEF%/$skillTwist/g;
                    $repeatedLine =~ s/%USERROWDEF%/class="userRow"/g;
                    $repeatedLine =~ s/%SKILLUSER%/$user/g;
                    $repeatedLine =~ s/%USERICON%/$open/g;

                    # rating
                    my $i = 0;
                    while ( $i < $obj_userSkill->rating ) {
                        my $ratingOut = $tmplRating;
                        $ratingOut =~ s/%RATING%/&nbsp;/g;
                        $ratingOut =~ s/%RATINGDEF%//g;
                        $repeatedLine .= $ratingOut;
                        $i++;
                    }
                    my $ratingOut = $tmplRating;
                    $ratingOut =~ s/%RATING%/$ratingPic/g;
                    $ratingOut =~ s/%RATINGDEF%/class='skillsRating'/g;
                    $repeatedLine .= $ratingOut;
                    $i++;
                    while ( $i <= 4 ) {
                        my $ratingOut = $tmplRating;
                        $ratingOut =~ s/%RATING%/&nbsp;/g;
                        $ratingOut =~ s/%RATINGDEF%//g;
                        $repeatedLine .= $ratingOut;
                        $i++;
                    }

                    # comment
                    $repeatedLine .= $tmplComment;

                    # comment link
                    if ( $obj_userSkill->comment ) {
                        my $url = Foswiki::Func::getScriptUrl(
                            'Main', 'WebHome', 'oops',
                            template => 'oopsgeneric',
                            param1   => 'Skills Plugin Comment',
                            param2   => "Comment for skill '"
                              . $obj_userSkill->name
                              . "' by $user",
                            param3 =>
"$user has logged the following comment next to skill '"
                              . $obj_userSkill->name . "'.",
                            param4 => $obj_userSkill->comment
                        );
                        $url .= ';cover=skills';
                        my $commentLink =
                            "<a id='comment|"
                          . $obj_userSkill->category . "|"
                          . $obj_userSkill->name
                          . "' class='SkillsPluginComments' href=\"$url\" target='_blank' >$commentPic</a>";
                        $repeatedLine =~ s/%COMMENTLINK%/$commentLink/g;
                    }
                    else {
                        $repeatedLine =~ s/%COMMENTLINK%//g;
                        $repeatedLine =~ s/%COMMENTOUT%//g;
                    }

                    $repeatedLine .= $tmplUserEnd;
                }
            }

            $repeatedLine =~ s/%SKILLICON%/$open/g;
            my $skillLink =
                '<span id="'
              . _urlEncode($catName)
              . _urlEncode($skillName)
              . '_twistyLink" class="SkillsPlugin-twisty-link">'
              . $skillName
              . '</span>';
            $repeatedLine =~ s/%SKILL%/$skillLink/g;
        }

        my $catTwist =
            '<span id="'
          . _urlEncode($catName)
          . '_twistyImage" class="SkillsPlugin-twisty-image"> '
          . $twistyCloseImg
          . '</span>';
        $repeatedLine =~ s/%CATEGORYICON%/$catTwist/g;
        my $catLink =
            '<span id="'
          . _urlEncode($catName)
          . '_twistyLink" class="SkillsPlugin-twisty-link">'
          . $catName
          . '</span>';
        $repeatedLine =~ s/%CATEGORY%/$catLink/g;
        $repeatedLine .= $tmplCatContEnd;
    }

    $out =~ s/%REPEAT%/$repeatedLine/g;

    my $twistyOpenImgSrc = _getImagesSrc()->{twistyopen};
    my $twistyCloseImgSrc = _getImagesSrc()->{twistyclose};
    my $jsVars           = "SkillsPlugin.vars.twistyState = '$twisty';";
    $jsVars .= "SkillsPlugin.vars.twistyOpenImgSrc = \"$twistyOpenImgSrc\";";
    $jsVars .= "SkillsPlugin.vars.twistyCloseImgSrc = \"$twistyCloseImgSrc\";";
    $jsVars .= 'SkillsPlugin.vars.browseSkills = 1;';
    _addHeads($jsVars);

    return $out;
}

# ========================= REST
sub _restAddNewCategory {

    my ( $session, $plugin, $verb, $response ) = @_;

    _Debug('REST handler: addNewCategory');

    my ( $web, $topic ) =
      Foswiki::Func::normalizeWebTopicName( undef,
        Foswiki::Func::getCgiQuery()->param('topic') );

    my $newCat = Foswiki::Func::getCgiQuery()->param('newcategory');

    unless ( Foswiki::Func::isAnAdmin() ) {
        if ( my $pref = Foswiki::Func::getPreferencesValue('ALLOWADDSKILLS') ) {
            my @allowedUsers = split( /,/, $pref );
            my $user = Foswiki::Func::getWikiName();
            return _returnFromRest( $web, $topic,
"Error adding category '$newCat' - You are not permitted to add categories or skills ($user)."
            ) unless grep( /$user/, @allowedUsers );
        }
    }

    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    my $error =
      Foswiki::Plugins::SkillsPlugin::SkillsStore->new()->addNewCategory($newCat);
    return _returnFromRest( $web, $topic,
        "Error adding category '$newCat' - $error" )
      if $error;

    _Log("Category $newCat added");

    # success
    return _returnFromRest( $web, $topic, "New category '$newCat' added." );
}

sub _restRenameCategory {

    _Debug('REST handler: renameCategory');

    my ( $web, $topic ) =
      Foswiki::Func::normalizeWebTopicName( undef,
        Foswiki::Func::getCgiQuery()->param('topic') );

    return _returnFromRest('Error - user is not an admin')
      unless Foswiki::Func::isAnAdmin();    # check admin

    my $oldCat = Foswiki::Func::getCgiQuery()->param('oldcategory')
      || return _returnFromRest( $web, $topic,
        "'oldcategory' parameter is required'" );
    my $newCat = Foswiki::Func::getCgiQuery()->param('newcategory')
      || return _returnFromRest( $web, $topic,
        "'newcategory' parameter is required'" );

    # rename in skills.txt
    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    my $renameSkillsError = Foswiki::Plugins::SkillsPlugin::SkillsStore->new()
      ->renameCategory( $oldCat, $newCat );
    return _returnFromRest( $web, $topic,
        "Error renaming category '$oldCat' to '$newCat' - $renameSkillsError" )
      if $renameSkillsError;

    # rename in users
    require Foswiki::Plugins::SkillsPlugin::UserSkills;
    my $renameUserError = Foswiki::Plugins::SkillsPlugin::UserSkills->new()
      ->renameCategory( $oldCat, $newCat );
    return _returnFromRest( $web, $topic,
        "Error renaming category '$oldCat' to '$newCat' - $renameUserError" )
      if $renameUserError;

    _Log("Category $oldCat renamed to $newCat");

    # success
    return _returnFromRest( $web, $topic,
        "Category '$oldCat' has been renamed to '$newCat'." );
}

sub _restDeleteCategory {
    _Debug('REST handler: deleteCategory');

    my $cat = Foswiki::Func::getCgiQuery()->param('oldcategory');

    my ( $web, $topic ) =
      Foswiki::Func::normalizeWebTopicName( undef,
        Foswiki::Func::getCgiQuery()->param('topic') );

    return _returnFromRest('Error - user is not an admin')
      unless Foswiki::Func::isAnAdmin();    # check admin

    # delete in skills.txt
    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    my $deleteStoreError =
      Foswiki::Plugins::SkillsPlugin::SkillsStore->new()->deleteCategory($cat);
    return _returnFromRest( $web, $topic,
        "Error deleting category '$cat' - $deleteStoreError" )
      if $deleteStoreError;

    # rename in users
    require Foswiki::Plugins::SkillsPlugin::UserSkills;
    my $deleteUserError =
      Foswiki::Plugins::SkillsPlugin::UserSkills->new()->deleteCategory($cat);
    return _returnFromRest( $web, $topic,
        "Error deleting category '$cat' - $deleteUserError" )
      if $deleteUserError;

    _Log("Category $cat deleted");

    # success
    return _returnFromRest( $web, $topic,
        "Category '$cat' has been deleted, along with its skills." );
}

# adds a new skill
# if the ALLOWADDSKILLS preference is set, only the listed people and admins can add skills
# otherwise everyone can
sub _restAddNewSkill {

    _Debug('REST handler: addNewCategory');

    my ( $web, $topic ) =
      Foswiki::Func::normalizeWebTopicName( undef,
        Foswiki::Func::getCgiQuery()->param('topic') );

    my $newSkill = Foswiki::Func::getCgiQuery()->param('newskill');
    my $cat      = Foswiki::Func::getCgiQuery()->param('incategory');

    unless ( Foswiki::Func::isAnAdmin() ) {
        if ( my $pref = Foswiki::Func::getPreferencesValue('ALLOWADDSKILLS') ) {
            my @allowedUsers = split( /,/, $pref );
            my $user = Foswiki::Func::getWikiName();
            return _returnFromRest( $web, $topic,
"Error adding skill '$newSkill' to category '$cat' - You are not permitted to add skills ($user)."
            ) unless grep( /$user/, @allowedUsers );
        }
    }

    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    my $error = Foswiki::Plugins::SkillsPlugin::SkillsStore->new()
      ->addNewSkill( $newSkill, $cat );
    return _returnFromRest( $web, $topic,
        "Error adding skill '$newSkill' to category '$cat' - $error" )
      if $error;

    _Log("Skill $newSkill added");

    # success
    return _returnFromRest( $web, $topic, "New skill '$newSkill' added." );
}

# renames a skill
# only admins can do this
sub _restRenameSkill {
    _Debug('REST handler: renameSkill');

    my ( $web, $topic ) =
      Foswiki::Func::normalizeWebTopicName( undef,
        Foswiki::Func::getCgiQuery()->param('topic') );

    return _returnFromRest('Error - user is not an admin')
      unless Foswiki::Func::isAnAdmin();    # check admin

    my ( $category, $oldSkill ) =
      split( /\|/, Foswiki::Func::getCgiQuery()->param('oldskill') )
      ;                                   # oldskill looks like Category|Skill
    my $newSkill = Foswiki::Func::getCgiQuery()->param('newskill');

    # rename in skills.txt
    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    my $renameStoreError = Foswiki::Plugins::SkillsPlugin::SkillsStore->new()
      ->renameSkill( $category, $oldSkill, $newSkill );
    return _returnFromRest( $web, $topic,
"Error renaming skill '$oldSkill' to '$newSkill' in category '$category' - $renameStoreError"
    ) if $renameStoreError;

    # rename in users
    require Foswiki::Plugins::SkillsPlugin::UserSkills;
    my $renameUserError = Foswiki::Plugins::SkillsPlugin::UserSkills->new()
      ->renameSkill( $category, $oldSkill, $newSkill );
    return _returnFromRest( $web, $topic,
"Error renaming skill '$oldSkill' to '$newSkill' in category '$category' - $renameUserError"
    ) if $renameUserError;

    _Log("Skill $oldSkill renamed to $newSkill in category $category");

    # success
    return _returnFromRest( $web, $topic,
        "Skill '$oldSkill' has been renamed to '$newSkill'." );
}

# moves a skill from one category to another
# only admins can do this
sub _restMoveSkill {
    _Debug('REST handler: moveSkill');

    my ( $web, $topic ) =
      Foswiki::Func::normalizeWebTopicName( undef,
        Foswiki::Func::getCgiQuery()->param('topic') );

    return _returnFromRest('Error - user is not an admin')
      unless Foswiki::Func::isAnAdmin();    # check admin

    my ( $oldCat, $skill ) =
      split( /\|/, Foswiki::Func::getCgiQuery()->param('movefrom') )
      ;                                   # movefrom looks like Category|Skill
    my $newCat = Foswiki::Func::getCgiQuery()->param('moveto');

    _Debug("$skill, $oldCat, $newCat");

    # rename in skills.txt
    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    my $moveStoreError = Foswiki::Plugins::SkillsPlugin::SkillsStore->new()
      ->moveSkill( $skill, $oldCat, $newCat );
    return _returnFromRest( $web, $topic,
"Error moving skill '$skill' from '$oldCat' to '$newCat' - $moveStoreError"
    ) if $moveStoreError;

    # rename in users
    require Foswiki::Plugins::SkillsPlugin::UserSkills;
    my $moveUserError = Foswiki::Plugins::SkillsPlugin::UserSkills->new()
      ->moveSkill( $skill, $oldCat, $newCat );
    return _returnFromRest( $web, $topic,
"Error moving skill '$skill' from '$oldCat' to '$newCat' - $moveUserError"
    ) if $moveUserError;

    _Log("Skill $skill moved from $oldCat to $newCat");

    # success
    return _returnFromRest( $web, $topic,
        "Skill '$skill' has been moved from '$oldCat' to '$newCat'." );
}

# deletes a skill from the skill database
# only admins can do this
sub _restDeleteSkill {
    _Debug('REST handler: deleteSkill');

    my ( $web, $topic ) =
      Foswiki::Func::normalizeWebTopicName( undef,
        Foswiki::Func::getCgiQuery()->param('topic') );

    return _returnFromRest('Error - user is not an admin')
      unless Foswiki::Func::isAnAdmin();    # check admin

    my ( $cat, $oldSkill ) =
      split( /\|/, Foswiki::Func::getCgiQuery()->param('oldskill') )
      ;                                   # oldskill looks like Category|Skill

    # delete in skills.txt
    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    my $deleteStoreError = Foswiki::Plugins::SkillsPlugin::SkillsStore->new()
      ->deleteSkill( $cat, $oldSkill );
    return _returnFromRest( $web, $topic,
        "Error deleting skill '$oldSkill' - $deleteStoreError" )
      if $deleteStoreError;

    # rename in users
    require Foswiki::Plugins::SkillsPlugin::UserSkills;
    my $deleteUserError = Foswiki::Plugins::SkillsPlugin::UserSkills->new()
      ->deleteSkill( $cat, $oldSkill );
    return _returnFromRest( $web, $topic,
        "Error deleting skill '$oldSkill' - $deleteUserError" )
      if $deleteUserError;

    _Log("Skill $oldSkill deleted");

    # success
    return _returnFromRest( $web, $topic,
        "Skill '$oldSkill' has been deleted from category '$cat'." );
}

# returns all categories in a comma seperated list
sub _restGetCategories {
    my ( $session, $plugin, $verb, $response ) = @_;

    _Debug('REST handler: getCategories');

    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    my $cats =
      Foswiki::Plugins::SkillsPlugin::SkillsStore->new()->getCategoryNames();

    return JSON::to_json($cats);
}

# returns all skills for a particular category in a comma seperated list
sub _restGetSkills {
    my ( $session, $plugin, $verb, $response ) = @_;

    _Debug('REST handler: getSkills');

    my $cat = Foswiki::Func::getCgiQuery()->param('category');
    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    my $categories = Foswiki::Plugins::SkillsPlugin::SkillsStore->new()
      ->eachCat();

    my $skills;
    while ( $categories->hasNext() ) {
        my $obj_cat = $categories->next();
        if ( $cat eq $obj_cat->name ) {
            $skills = $obj_cat->getSkillNames();
            return JSON::to_json($skills);
        }
    }
    return '[]';
}

# gets all the details for skills in a particular category for the
# current user. If 'cat' isn't given, get details for all categories.
# results is returned as a JSON hash indexed by category name, where
# each value is a hash indexed by skill name mapping to priority and
# comment.
sub _restGetSkillsAndDetails {
    my ( $session, $plugin, $verb, $response ) = @_;

    _Debug('REST handler: getSkillsAndDetails');

    my $cat   = Foswiki::Func::getCgiQuery()->param('category');

    my $user = Foswiki::Func::getWikiName();

    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    require Foswiki::Plugins::SkillsPlugin::UserSkills;

    if (!$cat) {
        my $cats =
          Foswiki::Plugins::SkillsPlugin::SkillsStore->new()
              ->getCategoryNames();
        $cat = join('|', @$cats);
    }

    my $categories =
      Foswiki::Plugins::SkillsPlugin::SkillsStore->new()->eachCat;
    my %data = ();
    my $us = Foswiki::Plugins::SkillsPlugin::UserSkills->new();
    while ( $categories->hasNext() ) {
        my $obj_cat = $categories->next();
        if ( $obj_cat->name() =~ /^($cat)$/ ) {
            my %cat_data;
            my $skills = $obj_cat->getSkillNames();
            foreach my $skill (@$skills) {
                my %user_data = ();
                my $obj_userSkill =
                  $us->getSkillForUser( $user, $skill, $cat );
                if ($obj_userSkill) {
                    # The user has the skill
                    $user_data{rating}   = $obj_userSkill->rating;
                    $user_data{comment}  = $obj_userSkill->comment;
                } # otherwise they don't have it
                $cat_data{$skill} = \%user_data;
            }
            $data{$obj_cat->name()} = \%cat_data;
        }
    }
    return JSON::to_json(\%data);
}

# Save changes made in the flat category form
sub _restSaveUserChanges {
    my ( $session, $plugin, $verb, $response ) = @_;

    _Debug('REST handler: getSkillDetails');

    my $query = Foswiki::Func::getCgiQuery();
    my $user = Foswiki::Func::getWikiName();

    require Foswiki::Plugins::SkillsPlugin::UserSkills;
    my $us = Foswiki::Plugins::SkillsPlugin::UserSkills->new();

    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    my $categories =
      Foswiki::Plugins::SkillsPlugin::SkillsStore->new()->eachCat;

    my $error;
    while ( !$error && $categories->hasNext() ) {
        my $obj_cat = $categories->next();
        my $cat = $obj_cat->name();
        my $skills = $obj_cat->getSkillNames();
        foreach my $skill (@$skills) {
            my $rating = $query->param(
                "editall.$cat.$skill-rating");
            my $comment = $query->param(
                "editall.$cat.$skill-comment");
            if (defined $rating || defined $comment) {
                $error = $us->addEditUserSkill(
                    $user, $cat, $skill, $rating, $comment );
                last if $error;
            }
        }
    }

    my $message;
    if ($error) {
        $message = "Error updating skills - $error";
    }
    else {
        $message = "Skills updated.";
    }
    return $message;
}

# gets all the details for a particular skill for the user logged in
# i.e. rating and comments
sub _restGetSkillDetails {
    my ( $session, $plugin, $verb, $response ) = @_;

    _Debug('REST handler: getSkillDetails');

    my $cat   = Foswiki::Func::getCgiQuery()->param('category');
    my $skill = Foswiki::Func::getCgiQuery()->param('skill');

    my $user = Foswiki::Func::getWikiName();

    require Foswiki::Plugins::SkillsPlugin::UserSkills;
    my $obj_userSkill = Foswiki::Plugins::SkillsPlugin::UserSkills->new()
      ->getSkillForUser( $user, $skill, $cat );

    unless ($obj_userSkill) {
        return '{}';
    }

    return JSON::to_json(
        {
            skill    => $obj_userSkill->name,
            category => $obj_userSkill->category,
            rating   => $obj_userSkill->rating,
            comment  => $obj_userSkill->comment,
        });
}

# allows a user to add a new skill or edit an existing one
sub _restAddEditSkill {
    my ( $session, $plugin, $verb, $response ) = @_;

    _Debug('REST handler: getSkillDetails');

    my $cat     = Foswiki::Func::getCgiQuery()->param('category');
    my $skill   = Foswiki::Func::getCgiQuery()->param('skill');
    my $rating  = Foswiki::Func::getCgiQuery()->param('addedit-skill-rating');
    my $comment = Foswiki::Func::getCgiQuery()->param('comment');

    die unless defined($cat) && defined($skill);

    my $user = Foswiki::Func::getWikiName();

    require Foswiki::Plugins::SkillsPlugin::UserSkills;
    my $error = Foswiki::Plugins::SkillsPlugin::UserSkills->new()
      ->addEditUserSkill( $user, $cat, $skill, $rating, $comment );

    my $message;
    if ($error) {
        $message = "Error adding/editing skill '$skill' - $error";
    }
    else {
        $message = "Skill '$skill' added/edited.";
    }

    return $message;
}

sub _restSearch {
    my $cat        = Foswiki::Func::getCgiQuery()->param('category');
    my $skill      = Foswiki::Func::getCgiQuery()->param('skill');
    my $ratingFrom = Foswiki::Func::getCgiQuery()->param('ratingFrom');
    my $ratingTo   = Foswiki::Func::getCgiQuery()->param('ratingTo');

    return 'Error: Category and Skill must be defined'
      unless ( $skill and $cat );

    my $out = Foswiki::Func::readTemplate('skillssearchresults');

    my $tmplRepeat = Foswiki::Func::readTemplate('skillssearchresultsrepeated');

    my ( undef, $tmplUserStart, $tmplUser, $tmplRating, $tmplComment,
        $tmplUserEnd )
      = split( /%SPLIT%/, $tmplRepeat );

    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    require Foswiki::Plugins::SkillsPlugin::UserSkills;
    my $skills     = Foswiki::Plugins::SkillsPlugin::SkillsStore->new();
    my $userSkills = Foswiki::Plugins::SkillsPlugin::UserSkills->new();

    # get image paths
    my $ratingPic      = _getImages()->{star};
    my $skillPic       = _getImages()->{open};
    my $commentPic     = _getImages()->{comment};
    my $twistyCloseImg = _getImages()->{twistyclose};

    my $repeatedLine;

    # hash of UserSkill objects keyed by user name
    my $users = Foswiki::Plugins::SkillsPlugin::UserSkills->new()
      ->getUsersForSkill( $skill, $cat );

    for my $user ( sort keys %{$users} ) {
        my $obj_userSkill = $users->{$user};

        my $lineOut;

        $lineOut .= $tmplUserStart;

        # skill
        $lineOut .= $tmplUser;

        # rating
        my $i = 1;
        while ( $i < $obj_userSkill->rating ) {
            my $ratingOut = $tmplRating;
            $ratingOut =~ s/%RATING%/&nbsp;/g;
            $ratingOut =~ s/%RATINGDEF%//g;
            $lineOut .= $ratingOut;
            $i++;
        }
        my $ratingOut = $tmplRating;
        $ratingOut =~ s/%RATING%/$ratingPic/g;
        $ratingOut =~ s/%RATINGDEF%/class='skillsRating'/g;
        $lineOut .= $ratingOut;
        $i++;
        while ( $i <= 4 ) {
            my $ratingOut = $tmplRating;
            $ratingOut =~ s/%RATING%/&nbsp;/g;
            $ratingOut =~ s/%RATINGDEF%//g;
            $lineOut .= $ratingOut;
            $i++;
        }

        # comment
        $lineOut .= $tmplComment;

        $lineOut .= $tmplUserEnd;

        # subsitutions
        $lineOut =~ s/%SKILLUSER%/$user/g;

        # comment link
        if ( $obj_userSkill->comment ) {
            my $url = Foswiki::Func::getScriptUrl(
                'Main', 'WebHome', 'oops',
                template => 'oopsgeneric',
                param1   => 'Skills Plugin Comment',
                param2   => "Comment for skill '"
                  . $obj_userSkill->name
                  . "' by $user",
                param3 =>
                  "$user has logged the following comment next to skill '"
                  . $obj_userSkill->name . "'.",
                param4 => $obj_userSkill->comment
            );
            $url .= ';cover=skills';
            my $commentLink =
                "<a id='comment|"
              . $obj_userSkill->category . "|"
              . $obj_userSkill->name
              . "' class='SkillsPluginComments' href=\"$url\" target='_blank' >$commentPic</a>";
            $lineOut =~ s/%COMMENTLINK%/$commentLink/g;
        }
        else {
            $lineOut =~ s/%COMMENTLINK%//g;
            $lineOut =~ s/%COMMENTOUT%//g;
        }

        $repeatedLine .= $lineOut;
    }

    $out =~ s/%REPEAT%/$repeatedLine/g;

    $out =~ s/%SEARCHCATEGORY%/$cat/g;
    $out =~ s/%SEARCHSKILL%/$skill/g;
    my $matches = keys( %{$users} );
    $out =~ s/%SEARCHMATCHES%/$matches/g;

    $out = Foswiki::Func::expandCommonVariables($out);

    #$out = Foswiki::Func::renderText( $out );

    return $out;
}

# ========================= FUNCTIONS
# returns all the categories in the defined format
sub _showCategories {
    my ( $format, $separator ) = @_;

    my $hasSeparator = $separator ne '' if $separator;
    my $hasFormat    = $format    ne '' if $format;

    $separator = ', ' unless ( $hasSeparator || $hasFormat );
    $separator ||= '';
    $separator =~ s/\$n/\n/go;

    $format = '$category' unless $hasFormat;
    $format .= "\n" unless $separator;
    $format =~ s/\$n/\n/go;

    my $text = '';
    my $line = '';

    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    my $cats =
      Foswiki::Plugins::SkillsPlugin::SkillsStore->new()->getCategoryNames();

    $text = join(
        $separator,
        map {
            $line = $format if $format;
            $line =~ s/\$category/$_/go;
            $line;
          } @{$cats}
    );

    return $text;
}

# allows the user to print all skills in format of their choice
# this can be from a specific category, or all categories
sub _showSkills {

    my ( $cat, $format, $separator, $prefix, $suffix, $catSeparator ) = @_;

    my $hasSeparator = $separator ne '' if $separator;
    my $hasFormat    = $format    ne '' if $format;

    $separator = ', ' unless ( $hasSeparator || $hasFormat );
    $separator ||= '';
    $separator =~ s/\$n/\n/go;

    $format = '$skill' unless $hasFormat;
    $format .= "\n" unless $separator;
    $format =~ s/\$n/\n/go;

    $prefix =~ s/\$n/\n/go if $prefix;
    $suffix =~ s/\$n/\n/go if $suffix;

    my $text = '';
    my $line = '';

    # get all skills
    # if category is specified, only show skills in that category
    # else, show them all

    # iterator of all categories
    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    my $categories = Foswiki::Plugins::SkillsPlugin::SkillsStore->new()->eachCat;

    if ($cat) {    # category specified

        my $skills;

        while ( $categories->hasNext() ) {
            my $obj_cat = $categories->next();
            if ( $cat eq $obj_cat->name ) {
                $skills = $obj_cat->getSkillNames;
                last;
            }
        }

        $text = join(
            $separator,
            map {
                $line = $format;
                $line =~ s/\$skill/$_/go;
                $line;
              } @$skills
        );

        return $text;

    }

    # all skills and categories
    else {
        $catSeparator = "\n" unless ( defined $catSeparator && $catSeparator ne '' );

        while ( $categories->hasNext() ) {
            my $obj_cat    = $categories->next();
            my $prefixLine = $prefix;
            $prefixLine =~ s/\$category/$obj_cat->name/goe;
            $prefixLine =~ s/\$n/\n/go;
            $text .= $prefixLine;

            $text .= join(
                $separator,
                map {
                    $line = $format;
                    $line =~ s/\$category/$obj_cat->name/goe;
                    $line =~ s/\$skill/$_/go;
                    $line;
                  } @{ $obj_cat->getSkillNames }
            );

            my $suffixLine = $suffix || '';
            $suffixLine =~ s/\$category/$obj_cat->name/goe;
            $suffixLine =~ s/\$n/\n/go;
            $text .= $suffixLine;

            # seperate each category
            $text .= $catSeparator;
        }

        return $text;
    }
}

# ========================= UTILITIES
sub _addHeads {

    return if $doneHeads;
    $doneHeads = 1;

    # js vars
    my $jsVars;
    if ( my $vars = shift ) {
        $jsVars =
          'if( !SkillsPlugin ) var SkillsPlugin = {}; SkillsPlugin.vars = {}; '
          ;    # create namespace in JS
        $jsVars .= $vars;
    }
    if ( Foswiki::Func::isGuest() ) {
        $jsVars .= 'SkillsPlugin.vars.loggedIn = 0;';
    }
    else {
        $jsVars .= 'SkillsPlugin.vars.loggedIn = 1;';
    }

# yui
# adds the YUI Javascript files from header
# these are from the YahooUserInterfaceContrib, if installed
# or directly from the internet (See http://developer.yahoo.com/yui/articles/hosting/)
# TODO: Could be configurable?
    my $yui;
    eval 'use Foswiki::Contrib::YahooUserInterfaceContrib';
    if ( !$@ ) {
        _Debug('YahooUserInterfaceContrib is installed, using local files');
        $yui =
'<script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/YahooUserInterfaceContrib/build/yahoo-dom-event/yahoo-dom-event.js"></script>'
          . '<script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/YahooUserInterfaceContrib/build/connection/connection-min.js"></script>'
          . '<script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/YahooUserInterfaceContrib/build/element/element-beta-min.js"></script>'
          . '<script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/YahooUserInterfaceContrib/build/json/json-min.js"></script>'
          . '<script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/YahooUserInterfaceContrib/build/animation/animation-min.js"></script>'
          . '<script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/YahooUserInterfaceContrib/build/container/container-min.js"></script>'

          # style
          . '<link rel="stylesheet" type="text/css" href="%PUBURL%/%SYSTEMWEB%/YahooUserInterfaceContrib/build/container/assets/skins/sam/container.css" />';
    }
    else {
        _Debug(
            'YahooUserInterfaceContrib is not installed, using Yahoo servers');
        $yui =
'<script type="text/javascript" src="http://yui.yahooapis.com/2.5.2/build/yahoo-dom-event/yahoo-dom-event.js"></script>'
          . '<script type="text/javascript" src="http://yui.yahooapis.com/2.5.2/build/connection/connection-min.js"></script>'
          . '<script type="text/javascript" src="http://yui.yahooapis.com/2.5.2/build/element/element-beta-min.js"></script>'
          . '<script type="text/javascript" src="http://yui.yahooapis.com/2.5.2/build/json/json-min.js"></script>'
          . '<script type="text/javascript" src="http://yui.yahooapis.com/2.5.2/build/animation/animation-min.js"></script>'
          . '<script type="text/javascript" src="http://yui.yahooapis.com/2.5.2/build/container/container-min.js"></script>'

          # style
          . '<link rel="stylesheet" type="text/css" href="http://yui.yahooapis.com/2.5.2/build/container/assets/skins/sam/container.css" />';
    }

    # css
    my $urlPath = Foswiki::Func::getPubUrlPath() . '/' . $Foswiki::cfg{SystemWebName} . '/' . $pluginName;

    # add to head
    # FIXME: use the 'requires' parameter? for YUI?
    Foswiki::Func::addToHEAD( 'SKILLSPLUGIN_JS', <<THIS);
<style type="text/css" media="all">
 \@import url("$urlPath/style.css");
</style>
$yui
<style>
.skillsSpinner {
 width: 16px;
 height: 16px;
 margin: 0px;
 padding: 0px;
 background-image: url("$urlPath/spinner.gif");
}
</style>
<script language='javascript' type='text/javascript'>$jsVars</script>
<script src="$urlPath/main.js" language="javascript" type="text/javascript">
</script>
THIS
}

# Taken from TagMePlugin (http://twiki.org/cgi-bin/view/Plugins/TagMePlugin)
sub _urlEncode {
    my $text = shift;
    $text =~ s/([^0-9a-zA-Z-_.:~!*'()\/%])/'%'.sprintf('%02x',ord($1))/ge;
    return $text;
}

# returns a hash of image html elements
sub _getImages {

    my $docpath = Foswiki::Func::getPubUrlPath() . '/' .    # /pub/
      $Foswiki::cfg{SystemWebName} . '/' .              # System/
      'DocumentGraphics';                                 # doc topic

    my %images = (
        "twistyopen" =>
"<img width='16' alt='twisty open' align='top' src='$docpath/toggleopen.gif' height='16' border='0' />",
        "twistyclose" =>
"<img width='16' alt='twisty close' align='top' src='$docpath/toggleclose.gif' height='16' border='0' />",
        "star" =>
"<img width='16' alt='*' align='top' src='$docpath/stargold.gif' height='16' border='0' />",
        "open" =>
"<img width='16' alt='-' align='top' src='$docpath/dot_ur.gif' height='16' border='0' />",
        "comment" =>
"<img width='16' alt='+' class='SkillsPlugins-comment-img' align='top' src='$docpath/note.gif' height='16' border='0' />",
        "clear" =>
"<img width='16' alt='Clear' align='top' src='$docpath/choice-cancel.gif' height='16' border='0' />",
        "info" =>
"<img width='16' alt='Info' align='top' src='$docpath/info.gif' height='16' border='0' />"
    );
    return \%images;
}

# returns a hash of image paths
sub _getImagesSrc {

    my $docpath = Foswiki::Func::getPubUrlPath() . '/' .    # /pub/
      $Foswiki::cfg{SystemWebName} . '/' .              # System/
      'DocumentGraphics';                                 # doc topic

    my %images = (
        "twistyopen"  => "$docpath/toggleopen.gif",
        "twistyclose" => "$docpath/toggleclose.gif"
    );
    return \%images;
}

# formats a suitible return message from rest functions
sub _returnFromRest {
    my ( $web, $topic, $message ) = @_;

    $message = _urlEncode($message);

    my $url =
        Foswiki::Func::getScriptUrl( $web, $topic, 'view' )
      . '?skillsmessage='
      . $message;
    Foswiki::Func::redirectCgiQuery( undef, $url );
}

# =========================
sub _Debug {
    my $text = shift;
    my $debug = $Foswiki::cfg{Plugins}{$pluginName}{Debug} || 0;
    Foswiki::Func::writeDebug("- Foswiki::Plugins::${pluginName}: $text") if $debug;
}

sub _Warn {
    my $text = shift;
    Foswiki::Func::writeWarning("- Foswiki::Plugins::${pluginName}: $text");
}

# logs actions
# FIXME - should write our own log in work area
sub _Log {
    return;
    my ($message) = @_;

    my $logAction = $Foswiki::cfg{Plugins}{$pluginName}{Log} || 1;
    return unless $logAction;

    my $user = Foswiki::Func::getWikiName();

    my $out = "| date,time | $user | $message |";

    _Debug("Logged: $out");
}

1;
