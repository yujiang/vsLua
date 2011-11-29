--------------------------------------------------
-- Online Mods Panel
--------------------------------------------------
include( "InstanceManager" );

-------------------------------
-- Global constants
-------------------------------
g_InstanceManager = InstanceManager:new( "ListingButtonInstance", "Button", Controls.ListingStack );
g_DetailLabels = InstanceManager:new("DetailLabelInstance", "Label", Controls.DetailLabelsStack);
g_DetailValues = InstanceManager:new("DetailValueInstance", "Label", Controls.DetailValuesStack);
g_Categories = InstanceManager:new("CategoryInstance", "Category", Controls.CategoriesStack);
g_ItemsPerPage		= 20;	-- The number of listings per page.
g_NumPagerEntries	= 3;	-- The number of explicit pages to show in pager.

-- NOTE: I really dislike how unintuitive this is..
-- should be r,g,b,a instead of x,y,z,w
-- colors should range from [0,255] just like the XML rather than [0,1]

-- listing box default color.
--[[
ListingBoxDefaultColor = {
	x = 200/255,
	y = 200/255,
	z = 200/255,
	w = 128/255,
}
--]]

-- listing box highlight color.
ListingBoxHighlightColor = {
	x = 225/255,
	y = 225/255,
	z = 225/255,
	w = 225/255,
}

-- Sort Option Data
-- Contains all possible buttons which alter the listings sort order.
g_SortOptions = {
	{
		Button = Controls.SortbyTitle,
		ImageControl = Controls.SortbyTitleImage,
		Column = "ModTitle",
		DefaultDirection = "asc",
		CurrentDirection = nil,
	},
	{
		Button = Controls.SortbyNewest,
		ImageControl = Controls.SortbyNewestImage,
		Column = "DateUploaded",
		DefaultDirection = "desc",
		CurrentDirection = "desc",
	},
	{
		Button = Controls.SortbyMostDownloaded,
		ImageControl = Controls.SortbyMostDownloadedImage,
		Column = "Downloads",
		DefaultDirection = "desc",
		CurrentDirection = nil,
	},
	{
		Button = Controls.SortbyRating,
		ImageControl = Controls.SortbyRatingImage,
		Column = "Rating1",
		DefaultDirection = "desc",
		CurrentDirection = nil,
	},
};

g_PagerControls = {
	Controls.FirstPage,
	Controls.PrevPage,
	Controls.NextPage,
	Controls.LastPage,
	Controls.PrevPageItem1,
	Controls.PrevPageItem2,
	Controls.NextPageItem1,
	Controls.NextPageItem2,
};

-- All of the columns retrieved during a listing query.
g_ModListingsColumns = {"ModID", "ModTitle", "ModTeaser"};

-- All of the columns retrieved during a details query.
g_ModDetailsColumns = {
		"recordid", 	 	
        "ownerid", 		
        "ModID",
        "ModVersion",
        "ModStatus",
        "ModTitle",
        "ModTeaser",
        "ModDescription",
        "UploadedBy",
        "DateUploaded",
        "Authors", 		
        "SpecialThanks",
        "DownloadURL",	
        "Rating1", 		
        "Rating2",
        "Rating3",
        "Downloads",
        "NeedsModeration",
        "num_ratings",
        "average_rating" 
};

-------------------------------
-- Global variables
-------------------------------
m_Queries = {};		-- A table containing all active queries.
m_UpdateTasks = {};	-- A table containing all the dynamic tasks to perform during update.
g_CurrentPage = 1;	-- The current page.
g_NumPages = 1;		-- The number of pages to display.
g_SortedMods = {};		-- A sorted array of installed mods.
g_FilterString = "";	-- The current database filter.
g_OrderBy = "";			-- The current database sorter.
g_SelectedCategories = {}; -- The currently selected categories.
g_CurrentListingsState = "waiting";
g_CurrentDetailsState = "message";

---------------------------------------------------------------------
-- RefreshListingsResults
-- This function gets called after the listings query has finished.
---------------------------------------------------------------------
function RefreshListingsResults(listingResults)
	g_InstanceManager:ResetInstances();
	
	local statusCode = listingResults.StatusCode();
	print(statusCode);
	if(statusCode ~= 0) then
		HandleListingsError(statusCode);
		return;
	end
		
	local count = 0;	 
	while(listingResults.Step()) do	
		local listing = g_InstanceManager:GetInstance();
		
		local modID = listingResults.GetValue("ModID");
		
		listing.Title:SetText(listingResults.GetValue("ModTitle") or "");
		listing.Teaser:SetText(listingResults.GetValue("ModTeaser") or "");
				 
		listing.Button:RegisterCallback( Mouse.eMouseEnter, OnListingMouseEnter);
		listing.Button:RegisterCallback( Mouse.eMouseExit, OnListingMouseExit);
		listing.Button:RegisterCallback( Mouse.eLClick, function() OnListingClicked(modID); end);
		
		count = count + 1;
	end

	Controls.ListingStack:CalculateSize();
	Controls.ListingStack:ReprocessAnchoring();

	Controls.ListingScrollPanel:CalculateInternalSize();
	
	if(count == 0) then
		local message = Locale.ConvertTextKey("TXT_KEY_MODDING_RESULTS_EMPTY");
		SetListingsMessage(message);
		SetListingsState("message");
	else	
		SetListingsState("results");
	end
end

function SetListingsMessage(message)
	Controls.ListingsMessageLabel:SetText(message);
end

function SetListingsState(state)
	
	if(state ~= g_CurrentListingsState) then
		Controls.ListingsResults:SetHide(true);
		Controls.ListingsWaiting:SetHide(true);
		Controls.ListingsMessage:SetHide(true);
		
		if(state == "results") then
			Controls.ListingsResults:SetHide(false);
		elseif(state == "waiting") then
			Controls.ListingsWaiting:SetHide(false);
		elseif(state == "message") then
			Controls.ListingsMessage:SetHide(false);
		end
		
		g_CurrentListingsState = state;
	end
end

function SetDetailsState(state)
	
	if(state ~= g_CurrentDetailsState) then	
		Controls.DetailsResults:SetHide(true);
		Controls.DetailsWaiting:SetHide(true);
		Controls.DetailsMessage:SetHide(true);
	
		if(state == "results") then
			Controls.DetailsResults:SetHide(false);
		elseif(state == "waiting") then
			Controls.DetailsWaiting:SetHide(false);
		elseif(state == "message") then
			Controls.DetailsMessage:SetHide(false);
		end
		
		g_CurrentDetailsState = state;
	end
end

function HandleListingsError(status)
	local errorMessages = {
		[2] = "TXT_KEY_MODDING_ERROR_SERVICE_DISABLED",
		[3] = "TXT_KEY_MODDING_ERROR_CONNETION_TIMEOUT",
		[4] = "TXT_KEY_MODDING_ERROR_CONNECTION",
		[16] = "TXT_KEY_MODDING_ERROR_ALREADY_RATED",
		[23] = "TXT_KEY_MODDING_ERROR_REQUEST_CANCELLED",
		[25] = "TXT_KEY_MODDING_ERROR_HTTP_UNAUTHORIZED",
		[26] = "TXT_KEY_MODDING_ERROR_HTTP_FORBIDDEN",
		[27] = "TXT_KEY_MODDING_ERROR_HTTP_FILE_NOT_FOUND",
		[28] = "TXT_KEY_MODDING_ERROR_HTTP_REQUEST_REJECTED",
		[29] = "TXT_KEY_MODDING_ERROR_HTTP_SERVER_ERROR",
	}
	
	local errorMessage = errorMessages[status];
	if(errorMessage == nil) then
		errorMessage = "TXT_KEY_MODDING_ERROR_GENERIC";
	end
	
	SetListingsMessage(Locale.ConvertTextKey(errorMessage));
	SetListingsState("message");
end

-- Callback when a category is selected.
function CategorySelected(option)

	if(option == nil) then
		g_SelectedCategories = {};
	else 
		-- For Now we only care about a single category but later we'll support multiple.	
		if(g_SelectedCategories[option] == nil) then
			g_SelectedCategories[option] = true;
		else
			g_SelectedCategories[option] = nil;
		end
	end

	UpdateCategoryDisplay();
	UpdateListingsFilter();
end

-- Updates the filter string based on selected categories.
function UpdateListingsFilter()

	local count = table.count(g_SelectedCategories);
	if(count > 0) then
		g_FilterString = "ModID in (select ModID from dev_civ5_Media_ModInfo_Categories_xref where";
		local first = true;
		for k,v in pairs(g_SelectedCategories) do
			if(first) then
				g_FilterString = string.format("%s CatID = %i", g_FilterString, k);
				first = false;
			else
				g_FilterString = string.format("%s or CatID = %i", g_FilterString, k);
			end
		end
		
		g_FilterString = g_FilterString .. ")";
	else
		g_FilterString = "";
	end
	print(g_FilterString);
	
	SetPage(1, true);
	RefreshPager();
end

-- Updates the display state of categories.
function UpdateCategoryDisplay()
	
	local count = table.count(g_SelectedCategories);
	
	if(count > 0) then
		g_AvailableCategories.All.CheckBox:SetTextureOffsetVal(0, 0);
	else
		g_AvailableCategories.All.CheckBox:SetTextureOffsetVal(0, 65);
	end
	
	for i,v in ipairs(g_AvailableCategories) do
		if(g_SelectedCategories[v.ID] == true) then
			v.CheckBox:SetTextureOffsetVal(0, 65);
		else
			v.CheckBox:SetTextureOffsetVal(0, 0);
		end
	end
end

-- Refreshes the category list based on results.
function RefreshCategoryResults(categoryResults)
	
	g_Categories:ResetInstances();
	g_AvailableCategories = {};
	
	local statusCode = categoryResults.StatusCode();
	print(statusCode);
	if(statusCode ~= 0) then
		print("ZOMG CATEGORY ERROR!!!");
		return;
	end
	
	-- This function creates a record count query that obtains the number of records per category
	-- It then refreshes the control to be CategoryName (RecordCount) 
	function UpdateCategoryRecordCount(control, categoryName, catID)
		control:SetText(categoryName .. " (...)");

		local filter = "";
		if(catID ~= nil) then
			filter = "ModID in (select ModID from dev_civ5_Media_ModInfo_Categories_xref where CatID = ";
			filter = filter .. catID .. " )";
		end
		
		local query = Modding.RecordCountQuery("Media_ModInfo", filter, true);
		ExecuteWhenQueryFinishes(query, function(query)
			local count = query.RecordCount();
			control:SetText(categoryName .. " (" .. count .. ")");
			if(count > 0) then
				control:SetHide(false);
			end
		end);
	end

	-- Always have an "ALL" category at the very top.
	local allCategories = g_Categories:GetInstance();
	local allCategoriesText = Locale.ConvertTextKey("TXT_KEY_MODDING_CATEGORIES_ALL");
	allCategories.Category:RegisterCallback(Mouse.eLClick, function() CategorySelected(nil); end);
	g_AvailableCategories.All = {Control = allCategories.Category, CheckBox = allCategories.CheckBox};
	UpdateCategoryRecordCount(allCategories.Category, allCategoriesText); 

	-- Iterate through all dynamic categories.
	while(categoryResults.Step()) do	
		local category = g_Categories:GetInstance();
		local catID = categoryResults.GetValue("recordid");
		local catName = categoryResults.GetValue("CatName");
		print(catName);
		
		category.Category:RegisterCallback(Mouse.eLClick, function() CategorySelected(catID); end);
	
		table.insert(g_AvailableCategories, {Control = category.Category, CheckBox = category.CheckBox, ID = catID});
		
		category.Category:SetHide(true);
		UpdateCategoryRecordCount(category.Category, catName, catID);
		
	end
	
	UpdateCategoryDisplay();
end

-- Triggers the refresh of the entire category list from the server.
function RefreshCategories()
	local query = Modding.OnlineQuery("Media_ModInfo_Categories", {"recordid", "CatName"}, "", "", 50, 0);
	ExecuteWhenQueryFinishes(query, RefreshCategoryResults);
end


---------------------------------------------------------------------
-- SetPage
-- This function gets called when the page is changed and listings 
-- need to be refreshed.
---------------------------------------------------------------------
function SetPage(page, forceRefresh)
	if(g_CurrentPage ~= page or forceRefresh) then
		g_InstanceManager:ResetInstances();
		
		local offset = g_ItemsPerPage * (page - 1);
		local query = Modding.OnlineQuery("Media_ModInfo", g_ModListingsColumns, g_FilterString, g_OrderBy, g_ItemsPerPage, offset);
		ExecuteWhenQueryFinishes(query, RefreshListingsResults);
		SetListingsState("waiting");
	end

	g_CurrentPage = page;
	
	UpdatePagerDisplay();
end

function UpdatePagerDisplay()
	Controls.FirstPage:SetHide(g_CurrentPage <= 1)
	Controls.PrevPage:SetHide(g_CurrentPage <= 1);
	
	Controls.NextPage:SetHide(g_CurrentPage >= g_NumPages);
	Controls.LastPage:SetHide(g_CurrentPage >= g_NumPages);
	
	Controls.PrevPageItem1:SetHide(true);
	Controls.PrevPageItem2:SetHide(true);
	Controls.NextPageItem1:SetHide(true);
	Controls.NextPageItem2:SetHide(true);
	
	Controls.CurrentPage:SetHide(g_NumPages == 1);
	Controls.CurrentPage:SetText(g_CurrentPage);
	
	if(g_CurrentPage - 1 > 0) then
		Controls.PrevPageItem1:SetText(g_CurrentPage - 1);
		Controls.PrevPageItem1:SetHide(false);		
	
		if(g_CurrentPage - 2 > 0) then
			Controls.PrevPageItem2:SetText(g_CurrentPage - 2);
			Controls.PrevPageItem2:SetHide(false);		
		end
	end
	
	if(g_CurrentPage + 1 <= g_NumPages) then
		Controls.NextPageItem1:SetText(g_CurrentPage + 1);
		Controls.NextPageItem1:SetHide(false);
	
	
		if(g_CurrentPage + 2 <= g_NumPages) then
			Controls.NextPageItem2:SetText(g_CurrentPage + 2);
			Controls.NextPageItem2:SetHide(false);
		end
	end
end

-- Queries the server for how many records match a given filter.
function RefreshPager(forceRefresh)

	if(forchRefresh) then
		-- Hide pager controls
		for i,v in ipairs(g_PagerControls) do
			v:SetHide(true);
		end
		
		-- Trigger a new pager query
		local query = Modding.RecordCountQuery("Media_ModInfo", g_FilterString);
		ExecuteWhenQueryFinishes(query, function(query)
			local count = query.RecordCount();
			g_NumPages = math.ceil(count / g_ItemsPerPage);
			UpdatePagerDisplay();
		end);
	end
end

-- Register paging specific control callbacks
function RegisterPagingControls()

	Controls.FirstPage:RegisterCallback(Mouse.eLClick, function() SetPage(1); end);
	Controls.PrevPage:RegisterCallback(Mouse.eLClick, function() SetPage(g_CurrentPage - 1); end);
		
	Controls.NextPage:RegisterCallback(Mouse.eLClick, function() SetPage(g_CurrentPage + 1); end);
	Controls.LastPage:RegisterCallback(Mouse.eLClick, function() SetPage(g_NumPages); end);
		
	Controls.PrevPageItem1:RegisterCallback(Mouse.eLClick, function() SetPage(g_CurrentPage - 1); end);
	Controls.PrevPageItem2:RegisterCallback(Mouse.eLClick, function() SetPage(g_CurrentPage - 2); end);
	Controls.NextPageItem1:RegisterCallback(Mouse.eLClick, function() SetPage(g_CurrentPage + 1); end);
	Controls.NextPageItem2:RegisterCallback(Mouse.eLClick, function() SetPage(g_CurrentPage + 2); end);
end

-- Callback for when sort options are selected.
function SortOptionSelected(option)
	-- Current behavior is to only have 1 sort option enabled at a time 
	-- though the rest of the structure is built to support multiple in the future.
	-- If a sort option was selected that wasn't already selected, use the default 
	-- direction.  Otherwise, toggle to the other direction.
	for i,v in ipairs(g_SortOptions) do
		if(v == option) then
			if(v.CurrentDirection == nil) then			
				v.CurrentDirection = v.DefaultDirection;
			else
				if(v.CurrentDirection == "asc") then
					v.CurrentDirection = "desc";
				else
					v.CurrentDirection = "asc";
				end
			end
		else
			v.CurrentDirection = nil;
		end
	end
	
	UpdateSortOptionsDisplay();
	UpdateSortOrder();
end

-- Registers the sort option controls click events
function RegisterSortOptions()
	for i,v in ipairs(g_SortOptions) do
		if(v.Button ~= nil) then
			v.Button:RegisterCallback(Mouse.eLClick, function() SortOptionSelected(v); end);
		end
	end
end

-- Builds the orderBy string and updates the page if it's changed
function UpdateSortOrder()
	local orderBy = nil;
	for i,v in ipairs(g_SortOptions) do
		if(v.CurrentDirection ~= nil) then
			if(orderBy ~= nil) then
				orderBy = string.format("%s, %s %s", orderBy, v.Column, v.CurrentDirection);
			else
				orderBy = string.format("%s %s", v.Column, v.CurrentDirection);
			end
		end
	end
	
	if(orderBy ~= g_OrderBy) then
		g_OrderBy = orderBy;
		SetPage(g_CurrentPage, true)
	end
end

-- Updates the control states of sort options
function UpdateSortOptionsDisplay()
	for i,v in ipairs(g_SortOptions) do
		local imageControl = v.ImageControl;
		if(imageControl ~= nil) then
			if(v.CurrentDirection == nil) then
				imageControl:SetHide(true);
			else
				local imageToUse = "SortAscending.dds";
				if(v.CurrentDirection == "desc") then
					imageToUse = "SortDescending.dds";
				end
				imageControl:SetTexture(imageToUse);
				
				imageControl:SetHide(false);
			end
		end
	end

end
 
--------------------------------------------------------
-- Listing Item Event Handlers
--------------------------------------------------------
function RefreshModInfo(modInfoResults)
	
	-- Step to the first row of the mod info
	-- Currently, this is the only row we care about.
	modInfoResults.Step();
	
	function GetField(name)
		return modInfoResults.GetValue(name);
	end
	
	g_ModInfo = {};
	
	-- Pull data from results
	local ModID = GetField("ModID") or "";
	local ModTitle = GetField("ModTitle") or "";
	local ModVersion = GetField("ModVersion");
	local ModStatus = GetField("ModStatus");
	local ModTeaser = GetField("ModTeaser");
	local ModDescription = GetField("ModDescription") or "";
	local ModUploadedBy = GetField("UploadedBy");
	local ModDateUploaded = GetField("DateUploaded");
	local ModAuthors = GetField("Authors");
	local ModSpecialThanks = GetField("SpecialThanks");
	local ModFileName = GetField("FileName");
	local ModFileSize = GetField("FileSize");
	local ModDownloadUrl = GetField("DownloadUrl");
	local ModRating1 = GetField("Rating1");
	local ModDownloads = GetField("Downloads");
	local ModURL = GetField("DownloadUrl");
	local ModSafeFileName = ModFileName or (ModTitle .. ".civ5mod");
	
	--Refresh info based on data
	Controls.SelectedModName:SetText(ModTitle);
	Controls.SelectedModDescription:SetText(ModDescription);
		
	g_DetailLabels:ResetInstances();
	g_DetailValues:ResetInstances();
	
	local max_width = 0;
	function AddDetail(tag, value)
		local detail = g_DetailLabels:GetInstance();
		local detailValue = g_DetailValues:GetInstance();
		
		--We always want to at least supply 1 argument.
		local text = Locale.ConvertTextKey(tag);
		detail.Label:SetText(text);
		
		local size = detail.Label:GetSize();
		local width = size.x;
		if(width > max_width) then
			max_width = width;
		end
		 
		detailValue.Label:SetText(value or "");
	end	
	
	local version = string.format("%s %s", ModVersion or "", ModStatus or "");
	local file_size = FileSizeAsString(ModFileSize);

	AddDetail("TXT_KEY_MODDING_LABELVERSION", version);
	AddDetail("TXT_KEY_MODDING_LABELUPLOADEDBY", ModUploadedBy);
	AddDetail("TXT_KEY_MODDING_LABELAUTHOR", ModAuthors);
	if(ModSpecialThanks and #ModSpecialThanks > 0) then
		AddDetail("TXT_KEY_MODDING_LABELSPECIALTHANKS", ModSpecialThanks);
	end
	
	AddDetail("TXT_KEY_MODDING_LABELDOWNLOADS", ModDownloads);
	AddDetail("TXT_KEY_MODDING_LABELRATING", ModRating1);
	AddDetail("TXT_KEY_MODDING_LABELSIZE", file_size);
	
	
	local du = ModDateUploaded;
	local dateUploaded;
	if(du ~= nil) then
		dateUploaded = Locale.ConvertTextKey("TXT_KEY_MODDING_DATETIME", du.Month, du.Day, du.Year, du.Hour, du.Minute);
	end
	AddDetail("TXT_KEY_MODDING_LABELUPDATED", dateUploaded);
	
	AddDetail("TXT_KEY_MODDING_LABELCATEGORIES", ModCategories);
	 
	if(ModTags ~= nil) then
		AddDetail("TXT_KEY_MODDING_LABELTAGS", ModTags);
	end
	
	local stupid_size = Controls.DetailLabelsStack:GetSize();
	local height = stupid_size.y;
	Controls.DetailLabelsStack:SetOffsetVal(5, 0);
	Controls.DetailLabelsStack:SetSize{x = max_width,y = height};
	Controls.DetailValuesStack:SetOffsetVal(max_width + 15, 0);
	
	local homepage = Controls.ModHomePage;
	if(ModHomePage ~= nil) then
		homepage:SetText(ModHomePage);
		homepage:SetHide(false);
	else
		homepage:SetHide(true);
	end
	
	g_ModInfo.DownloadURL = ModURL;
	g_ModInfo.DownloadFileName = ModSafeFileName;
	g_ModInfo.Title = ModTitle;
	g_ModInfo.ID = ModID;
	
	
	-- Is the mod already installed?
	local alreadyInstalled = false;
	local installedMods = Modding.GetInstalledMods();
	local alreadyInstalledMod = installedMods[ModID];
	if(alreadyInstalledMod ~= nil) then
		if(alreadyInstalledMod.Version >= tonumber(ModVersion)) then
			alreadyInstalled = true; 
		end
	end
	
	-- Maybe we're downloading it?
	local downloadingMod = false;
	if(not alreadyInstalled) then
		local downloads = Modding.GetDownloadProgress();
		for i,v in ipairs(downloads) do
			if(v.Description == ModSafeFileName) then	
				if(v.State ~= 8 and v.State ~= 7) then	-- If it's not in a Completed or Cancelled state..
					downloadingMod = true;
					break;
				end
			end
		end
	end

	
	-- Update State	
	local detailsMessageText = nil;
	local detailsMessageColorset = "Green_Black";
	
	if(alreadyInstalled) then
		detailsMessageText = Locale.ConvertTextKey("TXT_KEY_MODDING_ALREADY_INSTALLED");
	elseif(downloadingMod) then
		detailsMessageText = Locale.ConvertTextKey("TXT_KEY_MODDING_DOWNLOADING");
	elseif(ModURL == nil or ModURL == "") then
		detailsMessageText = Locale.ConvertTextKey("TXT_KEY_MODDING_ERROR_INVALIDURL");
		detailsMessageColorset = "Red_Black";
	end
	
	local showMessage = (detailsMessageText ~= nil);
	Controls.DetailsActionMessage:SetHide(not showMessage);
	if(showMessage) then
		Controls.DetailsActionMessage:SetText(detailsMessageText);
		Controls.DetailsActionMessage:SetColorByName(detailsMessageColorset);
	end
	
	Controls.UpdateButton:SetHide(showMessage);	
	
	
	SetDetailsState("results");
end

function OnListingClicked(modID)
	print("Looking up info for "..modID);
	local filter = string.format("ModID = '%s'", modID);
	local query = Modding.OnlineQuery("Media_ModInfo", g_ModDetailsColumns, filter, "", 1, 0, false);
	ExecuteWhenQueryFinishes(query, RefreshModInfo);
	SetDetailsState("waiting");
end

-- BoxButtons currently do not support highlight colors via XML.
-- In these mouse events, we fake the highlight colors.
function OnListingMouseEnter(_, _, listing)
	listing:SetColor(ListingBoxHighlightColor);
end

function OnListingMouseExit(_, _, listing)
	listing:SetColor(ListingBoxDefaultColor);
end

function OnHomePageClicked()
	local url = g_SelectedModInfo.HomePage;
	if(url ~= nil) then
		Steam.ActivateGameOverlayToWebPage(url);
	end
end
Controls.ModHomePage:RegisterCallback(Mouse.eLClick, OnHomePageClicked);

function OnModUpdateClicked()
	if(g_ModInfo and g_ModInfo.DownloadURL) then
		Modding.DownloadMod(g_ModInfo.DownloadURL, g_ModInfo.DownloadFileName, g_ModInfo.DownloadFileName);
				
		-- Update State	
		local detailsMessageText = Locale.ConvertTextKey("TXT_KEY_MODDING_DOWNLOADING");
		local detailsMessageColorset = "Green_Black";
		
		Controls.DetailsActionMessage:SetHide(false);
		Controls.DetailsActionMessage:SetText(detailsMessageText);
		Controls.DetailsActionMessage:SetColorByName(detailsMessageColorset);
		
		Controls.UpdateButton:SetHide(true);
	end
end
Controls.UpdateButton:RegisterCallback(Mouse.eLClick, OnModUpdateClicked);
---------------------------------------------------------
-- Update Handling
---------------------------------------------------------
function OnUpdate(deltaTime)
	for q,f in pairs(m_Queries) do
		if(q.Finished()) then
			f(q);
			m_Queries[q] = nil;
		end
	end
				
	for i,v in ipairs(m_UpdateTasks) do
		v(deltaTime);
	end	
end
ContextPtr:SetUpdate(OnUpdate);

-- Waits for a query to finish, then executes the function.
function ExecuteWhenQueryFinishes(query, functionToExecute)
	m_Queries[query] = functionToExecute;
end

-- Adds a function to be called during an update.
function AddUpdateTask(task)
	table.insert(m_UpdateTasks, task);
end


function FileSizeAsString(size)
	size = size or 0;
	if(size > 1073741824) then
		return string.format("%d gb", size / 1073741824);
	elseif(size > 1048576) then
		return string.format("%d mb", size / 1048576);
	elseif(size > 1024) then
		return string.format("%d kb", size / 1024);
	else
		return string.format("%d b", size);
	end
end

---------------------------------------------------------
-- Initial State
---------------------------------------------------------
function Initialize()
	-- Update Meters
	
	local listingsWaitingPercent = 0;
	AddUpdateTask(function(deltaTime) 
		listingsWaitingPercent = listingsWaitingPercent + deltaTime;
		if(listingsWaitingPercent > 1) then
			listingsWaitingPercent = 0;
		end
		Controls.ListingsWaitingMeter:SetPercent(listingsWaitingPercent);
	
	end);
	
	local detailsWaitingPercent = 0.5;
	AddUpdateTask(function(deltaTime)
		detailsWaitingPercent = detailsWaitingPercent + deltaTime;
		if(detailsWaitingPercent > 1) then
			detailsWaitingPercent = 0;
		end
		Controls.DetailsWaitingMeter:SetPercent(detailsWaitingPercent);
	end);

end

Initialize();
RefreshCategories();
RegisterPagingControls();
RegisterSortOptions();
RefreshPager(true);
UpdateSortOptionsDisplay();
UpdateSortOrder();
