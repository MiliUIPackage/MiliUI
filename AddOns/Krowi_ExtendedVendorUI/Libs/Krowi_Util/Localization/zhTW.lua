--[[
    Copyright (c) 2023 Krowi

    All Rights Reserved unless otherwise explicitly stated.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
]]

local lib = LibStub("Krowi_Util-1.0");

if not lib then
	return;
end

if lib.IsLoaded_zhTW then
	return;
end
lib.IsLoaded_zhTW = true;

local L = LibStub("AceLocale-3.0"):NewLocale("Krowi_Util-1.0", "zhTW");
if not L then return end

L["Loaded"] = "已載入";
L["Loaded Desc"] = "與外掛套件有關的插件是否已載入。";
L["Requires a reload"] = "需要重新載入介面";
L["Profiles"] = "設定檔";
L["Checked"] = "已啟用";
L["Unchecked"] = "已停用";
L["Default value"] = "預設值";